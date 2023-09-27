{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Simplex.Chat.Archive
  ( exportArchive,
    importArchive,
    deleteStorage,
    sqlCipherExport,
    handleDBError,
  )
where

import qualified Codec.Archive.Zip as Z
import Control.Monad.Except
import Control.Monad.Reader
import Data.Functor (($>))
import qualified Data.Text as T
import qualified Database.SQLite3 as SQL
import Simplex.Chat.Controller
import Simplex.Messaging.Agent.Client (agentClientStore)
import Simplex.Messaging.Agent.Store.SQLite (SQLiteStore (..), sqlString)
import Simplex.Messaging.Util
import System.FilePath
import UnliftIO.Directory
import UnliftIO.Exception (SomeException, bracket, catch)
import qualified UnliftIO.Exception as E
import UnliftIO.STM
import UnliftIO.Temporary

archiveAgentDbFile :: String
archiveAgentDbFile = "simplex_v1_agent.db"

archiveChatDbFile :: String
archiveChatDbFile = "simplex_v1_chat.db"

archiveFilesFolder :: String
archiveFilesFolder = "simplex_v1_files"

exportArchive :: ChatMonad m => ArchiveConfig -> m ()
exportArchive cfg@ArchiveConfig {archivePath, disableCompression} =
  withTempDir cfg "simplex-chat." $ \dir -> do
    StorageFiles {chatDb, agentDb, filesPath} <- storageFiles
    copyFile chatDb $ dir </> archiveChatDbFile
    copyFile agentDb $ dir </> archiveAgentDbFile
    forM_ filesPath $ \fp ->
      copyDirectoryFiles fp $ dir </> archiveFilesFolder
    let method = if disableCompression == Just True then Z.Store else Z.Deflate
    Z.createArchive archivePath $ Z.packDirRecur method Z.mkEntrySelector dir

importArchive :: ChatMonad m => ArchiveConfig -> m [ArchiveError]
importArchive cfg@ArchiveConfig {archivePath} =
  withTempDir cfg "simplex-chat." $ \dir -> do
    Z.withArchive archivePath $ Z.unpackInto dir
    StorageFiles {chatDb, agentDb, filesPath} <- storageFiles
    backup chatDb
    backup agentDb
    copyFile (dir </> archiveChatDbFile) chatDb
    copyFile (dir </> archiveAgentDbFile) agentDb
    copyFiles dir filesPath
      `E.catch` \(e :: E.SomeException) -> pure [AEImport . ChatError . CEException $ show e]
  where
    backup f = whenM (doesFileExist f) $ copyFile f $ f <> ".bak"
    copyFiles dir filesPath = do
      let filesDir = dir </> archiveFilesFolder
      case filesPath of
        Just fp ->
          ifM
            (doesDirectoryExist filesDir)
            (copyDirectoryFiles filesDir fp)
            (pure [])
        _ -> pure []

withTempDir :: ChatMonad m => ArchiveConfig -> (String -> (FilePath -> m a) -> m a)
withTempDir cfg = case parentTempDirectory (cfg :: ArchiveConfig) of
  Just tmpDir -> withTempDirectory tmpDir
  _ -> withSystemTempDirectory

copyDirectoryFiles :: ChatMonad m => FilePath -> FilePath -> m [ArchiveError]
copyDirectoryFiles fromDir toDir = do
  createDirectoryIfMissing False toDir
  fs <- listDirectory fromDir
  foldM copyFileCatchError [] fs
  where
    copyFileCatchError fileErrs f =
      (copyDirectoryFile f $> fileErrs)
        `E.catch` \(e :: E.SomeException) -> pure (AEImportFile f (ChatError . CEException $ show e) : fileErrs)
    copyDirectoryFile f = do
      let fn = takeFileName f
          f' = fromDir </> fn
      whenM (doesFileExist f') $ copyFile f' $ toDir </> fn

deleteStorage :: ChatMonad m => m ()
deleteStorage = do
  StorageFiles {chatDb, agentDb, filesPath} <- storageFiles
  removeFile chatDb
  removeFile agentDb
  mapM_ removePathForcibly filesPath
  tmpPath <- readTVarIO =<< asks tempDirectory
  mapM_ removePathForcibly tmpPath

data StorageFiles = StorageFiles
  { chatDb :: FilePath,
    chatEncrypted :: TVar Bool,
    agentDb :: FilePath,
    agentEncrypted :: TVar Bool,
    filesPath :: Maybe FilePath
  }

storageFiles :: ChatMonad m => m StorageFiles
storageFiles = do
  liftIO $ putStrLn "LALAL 11"
  ChatController {chatStore, filesFolder, smpAgent} <- ask
  liftIO $ putStrLn "LALAL 12"
  let SQLiteStore {dbFilePath = chatDb, dbEncrypted = chatEncrypted} = chatStore
      SQLiteStore {dbFilePath = agentDb, dbEncrypted = agentEncrypted} = agentClientStore smpAgent
  liftIO $ putStrLn "LALAL 13"
  filesPath <- readTVarIO filesFolder
  liftIO $ putStrLn "LALAL 14"
  pure StorageFiles {chatDb, chatEncrypted, agentDb, agentEncrypted, filesPath}

sqlCipherExport :: forall m. ChatMonad m => DBEncryptionConfig -> m ()
sqlCipherExport DBEncryptionConfig {currentKey = DBEncryptionKey key, newKey = DBEncryptionKey key'} =
  when (key /= key') $ do
    liftIO $ putStrLn "LALAL 1"
    fs@StorageFiles {chatDb, chatEncrypted, agentDb, agentEncrypted} <- storageFiles
    liftIO $ putStrLn "LALAL 2"
    checkFile `with` fs
    liftIO $ putStrLn "LALAL 3"
    backup `with` fs
    liftIO $ putStrLn "LALAL 4"
    (export chatDb chatEncrypted >> export agentDb agentEncrypted)
      `catchChatError` \e -> tryChatError (restore `with` fs) >> throwError e
  where
    action `with` StorageFiles {chatDb, agentDb} = action chatDb >> action agentDb
    backup f = copyFile f (f <> ".bak")
    restore f = copyFile (f <> ".bak") f
    checkFile f = unlessM (doesFileExist f) $ throwDBError $ DBErrorNoFile f
    export f dbEnc = do
      liftIO $ putStrLn "LALAL 41"
      enc <- readTVarIO dbEnc
      liftIO $ putStrLn "LALAL 42"
      when (enc && null key) $ throwDBError DBErrorEncrypted
      liftIO $ putStrLn "LALAL 43"
      when (not enc && not (null key)) $ throwDBError DBErrorPlaintext
      liftIO $ putStrLn "LALAL 44"
      withDB (`SQL.exec` exportSQL) DBErrorExport
      liftIO $ putStrLn "LALAL 45"
      renameFile (f <> ".exported") f
      liftIO $ putStrLn "LALAL 46"
      withDB (`SQL.exec` testSQL) DBErrorOpen
      liftIO $ putStrLn "LALAL 47"
      atomically $ writeTVar dbEnc $ not (null key')
      liftIO $ putStrLn "LALAL 48"
      where
        withDB a err = handleDBError err $ bracket (SQL.open $ T.pack f) SQL.close a
        exportSQL =
          T.unlines $
            keySQL key
              <> [ "ATTACH DATABASE " <> sqlString (f <> ".exported") <> " AS exported KEY " <> sqlString key' <> ";",
                   "SELECT sqlcipher_export('exported');",
                   "DETACH DATABASE exported;"
                 ]
        testSQL =
          T.unlines $
            keySQL key'
              <> [ "PRAGMA foreign_keys = ON;",
                   "PRAGMA secure_delete = ON;",
                   "PRAGMA auto_vacuum = FULL;",
                   "SELECT count(*) FROM sqlite_master;"
                 ]
        keySQL k = ["PRAGMA key = " <> sqlString k <> ";" | not (null k)]

handleDBError :: forall m. ChatMonad m => (SQLiteError -> DatabaseError) -> IO () -> m ()
handleDBError err a =
  (liftIO a $> Nothing)
    `catch` checkSQLError
    `catch` (\(e :: SomeException) -> sqliteError' e)
    >>= mapM_ (throwDBError . err)
  where
    checkSQLError e = case SQL.sqlError e of
      SQL.ErrorNotADatabase -> pure $ Just SQLiteErrorNotADatabase
      _ -> sqliteError' e
    sqliteError' :: Show e => e -> m (Maybe SQLiteError)
    sqliteError' = pure . Just . SQLiteError . show
