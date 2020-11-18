{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}

-- | Well-structured updates/transforms to the AST.

module Inflex.Server.Transforms where

import qualified Data.Vector as V
import           Inflex.Display ()
import           Inflex.Parser
import qualified Inflex.Schema as Shared
import           Inflex.Types
import qualified Inflex.Types as Field (Field(..))
import qualified Inflex.Types as FieldE (FieldE(..))
import           RIO

--------------------------------------------------------------------------------
-- General dispatcher

applyUpdateToDocument :: Shared.Update -> Shared.InputDocument1 -> Shared.InputDocument1
applyUpdateToDocument (Shared.CellUpdate Shared.UpdateCell {uuid, update}) =
  case cmd of
    Shared.NewFieldUpdate newField -> addNewFieldToDocument uuid path newField
    Shared.DeleteFieldUpdate deleteField ->
      deleteFieldToDocument uuid path deleteField
    Shared.RenameFieldUpdate renameField ->
      renameFieldToDocument uuid path renameField
    Shared.CodeUpdate (Shared.Code code) -> mapUuid uuid (const code)
    Shared.AddToEndUpdate ->
      mapUuidPath uuid path Mapping {mapArray = addArrayItem, mapRecord = id}
    Shared.RemoveUpdate (Shared.Removal {index}) ->
      mapUuidPath uuid path Mapping {mapArray = removeArrayItem index, mapRecord = id}
  where
    Shared.UpdatePath {path, update = cmd} = update

--------------------------------------------------------------------------------
-- Handlers

addNewFieldToDocument ::
     Shared.UUID
  -> Shared.DataPath
  -> Shared.NewField
  -> Shared.InputDocument1
  -> Shared.InputDocument1
addNewFieldToDocument uuid0 path Shared.NewField {name = name0} Shared.InputDocument1 {cells} =
  Shared.InputDocument1 {cells = fmap apply cells}
  where
    apply same@Shared.InputCell1 {..} =
      if uuid == uuid0
        then Shared.InputCell1
               {code = addNewFieldInCode path (FieldName name0) code, ..}
        else same

deleteFieldToDocument ::
     Shared.UUID
  -> Shared.DataPath
  -> Shared.DeleteField
  -> Shared.InputDocument1
  -> Shared.InputDocument1
deleteFieldToDocument uuid0 path Shared.DeleteField {name = name0} Shared.InputDocument1 {cells} =
  Shared.InputDocument1 {cells = fmap apply cells}
  where
    apply same@Shared.InputCell1 {..} =
      if uuid == uuid0
        then Shared.InputCell1
               {code = deleteFieldInCode path (FieldName name0) code, ..}
        else same

renameFieldToDocument ::
     Shared.UUID
  -> Shared.DataPath
  -> Shared.RenameField
  -> Shared.InputDocument1
  -> Shared.InputDocument1
renameFieldToDocument uuid0 path Shared.RenameField {from,to=to0} Shared.InputDocument1 {cells} =
  Shared.InputDocument1 {cells = fmap apply cells}
  where
    apply same@Shared.InputCell1 {..} =
      if uuid == uuid0
        then Shared.InputCell1
               {code = renameFieldInCode path (FieldName from) (FieldName to0) code, ..}
        else same

-- TODO: Do something about errors occurring. And possibly type-check
-- the result of the document afterwards?

addNewFieldInCode :: Shared.DataPath -> FieldName -> Text -> Text
addNewFieldInCode path0 name code =
  case parseText "" code of
    Left {} -> code
    Right expr -> textDisplay (go path0 expr)
  where
    go :: Shared.DataPath -> Expression Parsed -> Expression Parsed
    go path =
      \case
        ArrayExpression array@Array {expressions, location}
          | Shared.DataElemOf _index path' <- path ->
            ArrayExpression
              (withFields
                 (\fields ->
                    fields <> [Field {location, name, typ = FreshType location}])
                 (array {expressions = fmap (go path') expressions}))
        RecordExpression record@Record {fields}
          | Shared.DataFieldOf index path' <- path ->
            RecordExpression
              record
                { fields =
                    fmap
                      (\(i, fielde@FieldE {expression}) ->
                         fielde
                           { FieldE.expression =
                               if i == index
                                 then go path' expression
                                 else expression
                           })
                      (zip [0 ..] fields)
                }
        RecordExpression record@Record {fields, location}
          | Shared.DataHere <- path ->
            RecordExpression
              record
                { fields =
                    fields <>
                    [ FieldE
                        { name
                        , expression =
                            HoleExpression Hole {location, typ = Nothing}
                        , location
                        }
                    ]
                }
        e -> e

withFields :: ([Field Parsed] -> [Field Parsed]) -> Array Parsed -> Array Parsed
withFields f array@Array {typ}
  | Just (ArrayType (RecordType (RowType (row@TypeRow {fields})))) <- typ =
    array { typ = Just (ArrayType (RecordType (RowType row {fields = f fields}))) }
withFields _f array = array

renameFieldInCode :: Shared.DataPath -> FieldName -> FieldName -> Text -> Text
renameFieldInCode path0 from to' code =
  case parseText "" code of
    Left {} -> code
    Right expr -> textDisplay (go path0 expr)
  where
    go :: Shared.DataPath -> Expression Parsed -> Expression Parsed
    go path =
      \case
        ArrayExpression array@Array {expressions}
          | Shared.DataElemOf _index path' <- path ->
            ArrayExpression
              (withFields
                 (\fields ->
                    map
                      (\f@Field {name} ->
                         if name == from
                           then f {Field.name = to'}
                           else f)
                      fields)
                 (array {expressions = fmap (go path') expressions}))
        RecordExpression record@Record {fields}
          | Shared.DataFieldOf index path' <- path ->
            RecordExpression
              record
                { fields =
                    fmap
                      (\(i, fielde@FieldE {expression}) ->
                         fielde
                           { FieldE.expression =
                               if i == index
                                 then go path' expression
                                 else expression
                           })
                      (zip [0 ..] fields)
                }
        RecordExpression record@Record {fields}
          | Shared.DataHere <- path ->
            RecordExpression
              record
                { fields =
                    fmap
                      (\field@FieldE {name} ->
                         if name == from
                           then field {FieldE.name = to'}
                           else field)
                      fields
                    -- ]
                }
        e -> e

deleteFieldInCode :: Shared.DataPath -> FieldName -> Text -> Text
deleteFieldInCode path0 name0 code =
  case parseText "" code of
    Left {} -> code
    Right expr -> textDisplay (go path0 expr)
  where
    go :: Shared.DataPath -> Expression Parsed -> Expression Parsed
    go path =
      \case
        ArrayExpression array@Array {expressions}
          | Shared.DataElemOf _index path' <- path ->
            ArrayExpression
              (withFields
                 (filter (not . (== name0) . Field.name))
                 (array {expressions = fmap (go path') expressions}))
        RecordExpression record@Record {fields}
          | Shared.DataFieldOf index path' <- path ->
            RecordExpression
              record
                { fields =
                    fmap
                      (\(i, fielde@FieldE {expression}) ->
                         fielde
                           { FieldE.expression =
                               if i == index
                                 then go path' expression
                                 else expression
                           })
                      (zip [0 ..] fields)
                }
        RecordExpression record@Record {fields}
          | Shared.DataHere <- path ->
            RecordExpression
              record {fields = filter (\FieldE {name} -> name /= name0) fields}
        e -> e

--------------------------------------------------------------------------------
-- Array

addArrayItem :: Array Parsed -> Array Parsed
addArrayItem array@Array {location, expressions} =
  array
    { expressions =
        expressions <> pure (HoleExpression Hole {location, typ = Nothing})
    }

removeArrayItem :: Int -> Array Parsed -> Array Parsed
removeArrayItem idx array@Array {expressions} =
  array
    { expressions =
        V.ifilter (\i _ -> i /= idx) expressions
    }

--------------------------------------------------------------------------------
-- Generic walkers

data Mapping = Mapping
  { mapArray :: Array Parsed -> Array Parsed
  , mapRecord :: Record Parsed -> Record Parsed
  }

-- | Change something at a path in a uuid in the document.
mapUuidPath ::
     Shared.UUID
  -> Shared.DataPath
  -> Mapping
  -> Shared.InputDocument1
  -> Shared.InputDocument1
mapUuidPath uuid path mapping = mapUuid uuid (mapPath path mapping)

-- | Change something at a uuid in the document.
mapUuid ::
     Shared.UUID
  -> (Text -> Text)
  -> Shared.InputDocument1
  -> Shared.InputDocument1
mapUuid uuid0 f Shared.InputDocument1 {cells} =
  Shared.InputDocument1 {cells = fmap apply cells}
  where
    apply same@Shared.InputCell1 {..} =
      if uuid == uuid0
        then Shared.InputCell1 {code = f code, ..}
        else same

-- | Change something at a path in the source code.
mapPath :: Shared.DataPath -> Mapping -> Text -> Text
mapPath path0 Mapping {mapArray,mapRecord} code =
  case parseText "" code of
    Left {} -> code
    Right expr -> textDisplay (go path0 expr)
  where
    go :: Shared.DataPath -> Expression Parsed -> Expression Parsed
    go path =
      \case
        ArrayExpression array@Array {expressions}
          | Shared.DataElemOf _index path' <- path ->
            ArrayExpression (array {expressions = fmap (go path') expressions})
        RecordExpression record@Record {fields}
          | Shared.DataFieldOf index path' <- path ->
            RecordExpression
              record
                { fields =
                    fmap
                      (\(i, fielde@FieldE {expression}) ->
                         fielde
                           { FieldE.expression =
                               if i == index
                                 then go path' expression
                                 else expression
                           })
                      (zip [0 ..] fields)
                }
        e
          | Shared.DataHere <- path ->
            case e of
              ArrayExpression array -> ArrayExpression (mapArray array)
              RecordExpression record -> RecordExpression (mapRecord record)
              _ -> e
          | otherwise -> e
