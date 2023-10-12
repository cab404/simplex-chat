{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Simplex.Chat.Store.Remote where

import Data.Int (Int64)
import Data.Text (Text)
import Database.SQLite.Simple (Only (..))
import qualified Database.SQLite.Simple as SQL
import qualified Simplex.Messaging.Agent.Store.SQLite.DB as DB
import Simplex.Chat.Remote.Types (RemoteCtrl (..), RemoteCtrlId, RemoteHost (..), RemoteHostId)
import Simplex.Messaging.Agent.Store.SQLite (maybeFirstRow)
import qualified Simplex.Messaging.Crypto as C

insertRemoteHost :: DB.Connection -> FilePath -> Text -> C.APrivateSignKey -> C.SignedCertificate -> IO RemoteHostId
insertRemoteHost db storePath displayName caKey caCert = do
  DB.execute db "INSERT INTO remote_hosts (store_path, display_name, ca_key, ca_cert) VALUES (?,?,?,?)" (storePath, displayName, caKey, C.SignedObject caCert)
  fromOnly . head <$> DB.query_ db "SELECT last_insert_rowid()"

getRemoteHosts :: DB.Connection -> IO [RemoteHost]
getRemoteHosts db =
  map toRemoteHost <$> DB.query_ db remoteHostQuery

getRemoteHost :: DB.Connection -> RemoteHostId -> IO (Maybe RemoteHost)
getRemoteHost db remoteHostId =
  maybeFirstRow toRemoteHost $
    DB.query db (remoteHostQuery <> " WHERE remote_host_id = ?") (Only remoteHostId)

remoteHostQuery :: SQL.Query
remoteHostQuery = "SELECT remote_host_id, store_path, display_name, ca_key, ca_cert, contacted FROM remote_hosts"

toRemoteHost :: (Int64, FilePath, Text, C.APrivateSignKey, C.SignedObject C.Certificate, Bool) -> RemoteHost
toRemoteHost (remoteHostId, storePath, displayName, caKey, C.SignedObject caCert, contacted) =
  RemoteHost {remoteHostId, storePath, displayName, caKey, caCert, contacted}

deleteRemoteHostRecord :: DB.Connection -> RemoteHostId -> IO ()
deleteRemoteHostRecord db remoteHostId = DB.execute db "DELETE FROM remote_hosts WHERE remote_host_id = ?" (Only remoteHostId)

insertRemoteCtrl :: DB.Connection -> Text -> C.KeyHash -> IO RemoteCtrlId
insertRemoteCtrl db displayName fingerprint = do
  DB.execute db "INSERT INTO remote_controllers (display_name, fingerprint) VALUES (?,?)" (displayName, fingerprint)
  fromOnly . head <$> DB.query_ db "SELECT last_insert_rowid()"

getRemoteCtrls :: DB.Connection -> IO [RemoteCtrl]
getRemoteCtrls db =
  map toRemoteCtrl <$> DB.query_ db remoteCtrlQuery

getRemoteCtrl :: DB.Connection -> RemoteCtrlId -> IO (Maybe RemoteCtrl)
getRemoteCtrl db remoteCtrlId =
  maybeFirstRow toRemoteCtrl $
    DB.query db (remoteCtrlQuery <> " WHERE remote_controller_id = ?") (Only remoteCtrlId)

getRemoteCtrlByFingerprint :: DB.Connection -> C.KeyHash -> IO (Maybe RemoteCtrl)
getRemoteCtrlByFingerprint db fingerprint =
  maybeFirstRow toRemoteCtrl $
    DB.query db (remoteCtrlQuery <> " WHERE fingerprint = ?") (Only fingerprint)

remoteCtrlQuery :: SQL.Query
remoteCtrlQuery = "SELECT remote_controller_id, display_name, fingerprint, accepted FROM remote_controllers"

toRemoteCtrl :: (Int64, Text, C.KeyHash, Maybe Bool) -> RemoteCtrl
toRemoteCtrl (remoteCtrlId, displayName, fingerprint, accepted) =
  RemoteCtrl {remoteCtrlId, displayName, fingerprint, accepted}

markRemoteCtrlResolution :: DB.Connection -> RemoteCtrlId -> Bool -> IO ()
markRemoteCtrlResolution db remoteCtrlId accepted =
  DB.execute db "UPDATE remote_controllers SET accepted = ? WHERE remote_controller_id = ? AND accepted IS NULL" (accepted, remoteCtrlId)

deleteRemoteCtrlRecord :: DB.Connection -> RemoteCtrlId -> IO ()
deleteRemoteCtrlRecord db remoteCtrlId =
  DB.execute db "DELETE FROM remote_controllers WHERE remote_controller_id = ?" (Only remoteCtrlId)
