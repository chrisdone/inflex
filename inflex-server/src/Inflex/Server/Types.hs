{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE Strict #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}

module Inflex.Server.Types where

import Data.Text (Text)
import Database.Persist
import Database.Persist.Sql
import Yesod hiding (Html)

newtype DocumentName = DocumentName Text
  deriving (Show, Read, PathPiece, Eq)

newtype Username = Username Text
  deriving (Show, Read, PathPiece, Eq)

newtype Password = Password Text
  deriving (Read, PathPiece, Eq, PersistFieldSql, PersistField)
instance Show Password where
  show _ = "Password _"

newtype Email = Email Text
  deriving (Show, Read, Eq, PersistFieldSql, PersistField)
