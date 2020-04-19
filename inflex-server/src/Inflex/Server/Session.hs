{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Session management.

module Inflex.Server.Session
  ( updateSession
  , requireSession
  , lookupSession
  , generateSession
  , assumeSession
  ) where

import           RIO (try)
import           Data.UUID as UUID
import           Data.UUID.V4 as UUID
import           Inflex.Server.App
import           Inflex.Server.Types
import           Yesod hiding (lookupSession)

assumeSession :: SessionState -> Handler (Entity Session)
assumeSession sessionState = do
  result <- lookupSession
  case result of
    Nothing -> do
      session <- runDB (generateSession sessionState)
      -- TODO: Set expiry, secure, etc.
      -- <https://hackage.haskell.org/package/cookie-0.4.0/docs/Web-Cookie.html#t:SetCookie>
      -- For some reason Set-Cookie sends two Set-Cookie headers, one
      -- with an empty value which breaks everything.
      addHeader
        "Set-Cookie"
        ("SESSION_UUID=" <>
         UUID.toText (unSessionUUID (sessionUuid (entityVal session))) <> "; Path=/")
      pure session
    Just session -> pure session

updateSession :: SessionId -> SessionState -> YesodDB App ()
updateSession sessionId state =
  update sessionId [SessionState =. state]

requireSession :: Route App -> Handler (Entity Session)
requireSession route = do
  result <- lookupSession
  case result of
    Nothing -> redirect route
    Just session -> pure session

lookupSession :: Handler (Maybe (Entity Session))
lookupSession = do
  result <- lookupCookie "SESSION_UUID"
  case result >>= UUID.fromText of
    Just sessionUUID -> runDB (querySession (SessionUUID sessionUUID))
    Nothing -> pure Nothing

querySession :: SessionUUID -> YesodDB App (Maybe (Entity Session))
querySession sessionUuid = do
  result <- try (selectFirst [SessionUuid ==. sessionUuid] [])
  case result of
    Left (_ :: PersistException) -> pure Nothing
    Right ok -> do
      liftIO (print ok)
      pure ok

generateSession :: SessionState -> YesodDB App (Entity Session)
generateSession sessionState = loop
  where
    loop = do
      uuid <- liftIO UUID.nextRandom
      let sessionUuid = SessionUUID uuid
          session = Session {sessionUuid, sessionState = sessionState}
      result <- insertUnique session
      case result of
        Nothing -> loop
        Just sessionId -> pure (Entity sessionId session)
