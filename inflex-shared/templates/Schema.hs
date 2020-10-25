{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE TypeApplications, ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric, NamedFieldPuns, RecordWildCards #-}
{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving, GeneralizedNewtypeDeriving #-}

-- | Shared data types.

module Inflex.Schema where

import           Control.Applicative
import           Data.Aeson (FromJSON(..), Options, ToJSON(..), defaultOptions, (.:), withObject, Value)
import           Data.Aeson.Types (Parser)
import           Data.Text (Text)
import           Data.Vector (Vector)
import qualified Data.Vector as V
import           Database.Persist.TH
import           GHC.Generics

--------------------------------------------------------------------------------
-- Types

newtype UUID = UUID Text
 deriving (Eq, Ord, FromJSON, ToJSON, Show)

$types

--------------------------------------------------------------------------------
-- Decoding options

opts :: Options
opts = defaultOptions

--------------------------------------------------------------------------------
-- Derivings

deriving instance Generic None
deriving instance Show None
instance ToJSON None
instance FromJSON None

deriving instance Generic Result
deriving instance Show Result
instance ToJSON Result
instance FromJSON Result

deriving instance Generic Tree1
deriving instance Show Tree1
instance ToJSON Tree1
instance FromJSON Tree1

deriving instance Generic Tree2
deriving instance Show Tree2
instance ToJSON Tree2
instance FromJSON Tree2

deriving instance Generic ResultTree
deriving instance Show ResultTree
deriving instance ToJSON ResultTree
instance FromJSON ResultTree where
  parseJSON j =
    fmap
      ResultTree
      (parseJSON j <|> fmap migrateV2 (parseJSON j) <|>
       fmap (migrateV2 . migrateV1) (parseJSON j))
    where
      migrateV1 :: Text -> Tree1
      migrateV1 text = MiscTree versionRefl text
      migrateV2 :: Tree1 -> Tree2
      migrateV2 =
        \case
          ArrayTree _ trees ->
            ArrayTree2 versionRefl NoOriginalSource (fmap migrateV2 trees)
          RecordTree _ fields ->
            RecordTree2
              versionRefl
              NoOriginalSource
              (fmap migrateV2Field fields)
            where migrateV2Field Field1 {..} =
                    Field2 {version = versionRefl, value = migrateV2 value, ..}
          MiscTree _ text -> MiscTree2 versionRefl NoOriginalSource text

deriving instance Generic CellError
deriving instance Show CellError
instance ToJSON CellError
instance FromJSON CellError

deriving instance Generic OriginalSource
deriving instance Show OriginalSource
instance ToJSON OriginalSource
instance FromJSON OriginalSource

deriving instance Generic Field1
deriving instance Show Field1
instance ToJSON Field1
instance FromJSON Field1

deriving instance Generic Field2
deriving instance Show Field2
instance ToJSON Field2
instance FromJSON Field2

deriving instance Generic Row
deriving instance Show Row
instance ToJSON Row
instance FromJSON Row

deriving instance Generic FillError
deriving instance Show FillError
instance ToJSON FillError
instance FromJSON FillError

deriving instance Generic InputDocument
deriving instance Show InputDocument
instance ToJSON InputDocument
instance FromJSON InputDocument

deriving instance Generic InputDocument1
deriving instance Show InputDocument1
instance ToJSON InputDocument1
instance FromJSON InputDocument1 where
  parseJSON =
    withObject
      "InputDocument1"
      (\o -> do
         cells <- o .: "cells" <|> fmap migrateV1 (o .: "cells")
         pure InputDocument1 {cells})
    where
      migrateV1 :: Vector InputCell -> Vector InputCell1
      migrateV1 =
        V.imap
          (\order InputCell {..} ->
             InputCell1 {version = versionRefl, order, ..})

deriving instance Generic InputCell1
deriving instance Show InputCell1
instance ToJSON InputCell1
instance FromJSON InputCell1

deriving instance Generic RefreshDocument
deriving instance Show RefreshDocument
instance ToJSON RefreshDocument
instance FromJSON RefreshDocument

deriving instance Generic OutputDocument
deriving instance Show OutputDocument
instance ToJSON OutputDocument
instance FromJSON OutputDocument

deriving instance Generic InputCell
deriving instance Show InputCell
instance ToJSON InputCell
instance FromJSON InputCell

deriving instance Generic OutputCell
deriving instance Show OutputCell
instance ToJSON OutputCell
instance FromJSON OutputCell

deriving instance Generic UpdateDocument
deriving instance Show UpdateDocument
instance ToJSON UpdateDocument
instance FromJSON UpdateDocument

deriving instance Generic Update
deriving instance Show Update
instance ToJSON Update
instance FromJSON Update

deriving instance Generic NewField
deriving instance Show NewField
instance ToJSON NewField
instance FromJSON NewField

deriving instance Generic RenameField
deriving instance Show RenameField
instance ToJSON RenameField
instance FromJSON RenameField

deriving instance Generic DeleteField
deriving instance Show DeleteField
instance ToJSON DeleteField
instance FromJSON DeleteField

deriving instance Generic UpdateCell
deriving instance Show UpdateCell
instance ToJSON UpdateCell
instance FromJSON UpdateCell

deriving instance Generic UpdatePath
deriving instance Show UpdatePath
instance ToJSON UpdatePath
instance FromJSON UpdatePath

deriving instance Generic PathUpdate
deriving instance Show PathUpdate
instance ToJSON PathUpdate
instance FromJSON PathUpdate

deriving instance Generic DataPath
deriving instance Show DataPath
instance ToJSON DataPath
instance FromJSON DataPath

deriving instance Real DocumentId
deriving instance Enum DocumentId
deriving instance Ord DocumentId
deriving instance Eq DocumentId
deriving instance Num DocumentId
deriving instance Integral DocumentId
deriving instance Generic DocumentId
deriving instance Show DocumentId
instance ToJSON DocumentId
instance FromJSON DocumentId

--------------------------------------------------------------------------------
-- Version infra

parseVersion :: forall v. Version v => Value -> Parser v
parseVersion j = do
  i <- parseJSON j
  if i == versionNumber (versionRefl :: v)
    then pure (versionRefl :: v)
    else fail
           ("Version mismatch, expected: " <> show (versionNumber (versionRefl :: v)) <>
            ", but got: " <>
            show i)

versionToJSON :: forall v. Version v => v -> Value
versionToJSON v = toJSON (versionNumber v)

--------------------------------------------------------------------------------
-- Versions

deriving instance Show Version1
instance Version Version1 where versionNumber _ = 1; versionRefl = Version1
instance FromJSON Version1 where parseJSON = parseVersion
instance ToJSON Version1 where toJSON = versionToJSON

deriving instance Show Version2
instance Version Version2 where versionNumber _ = 2; versionRefl = Version2
instance FromJSON Version2 where parseJSON = parseVersion
instance ToJSON Version2 where toJSON = versionToJSON

$(derivePersistFieldJSON "InputDocument")
$(derivePersistFieldJSON "OutputDocument")
$(derivePersistFieldJSON "InputCell")
$(derivePersistFieldJSON "OutputCell")

$(derivePersistFieldJSON "InputDocument1")
$(derivePersistFieldJSON "InputCell1")
