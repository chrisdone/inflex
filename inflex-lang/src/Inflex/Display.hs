{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE GADTs #-}
{-# OPTIONS -fno-warn-orphans #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Pretty printer for debugging.

module Inflex.Display where

import           Data.Aeson (encode)
import qualified Data.ByteString.Lazy as L
import           Data.Char (isAlphaNum)
import           Data.Coerce
import           Data.List
import qualified Data.Text as T
import           Data.Vector (Vector)
import qualified Data.Vector as V
import           Inflex.Decimal
import           Inflex.Location
import           Inflex.Types
import           Inflex.Types.SHA512
import           RIO hiding(Alternative)

-- TODO: Avoid unneeded parens.

instance Display (Expression Resolved) where
  display =
    \case
      RecordExpression record -> display record
      PropExpression prop -> display prop
      HoleExpression hole -> display hole
      ArrayExpression array -> display array
      VariantExpression variant -> display variant
      LiteralExpression literal -> display literal
      LambdaExpression lambda -> display lambda
      ApplyExpression apply -> display apply
      VariableExpression variable -> display variable
      GlobalExpression global -> display global
      LetExpression let' -> display let'
      IfExpression if' -> display if'
      CaseExpression case' -> display case'
      BoundaryExpression boundary' -> display boundary'
      EarlyExpression early' -> display early'
      InfixExpression infix' -> display infix'

instance Display (Case Resolved) where
  display Case{..} = "case " <> display scrutinee <> " {" <>
    mconcat (intersperse ", " (map display (toList alternatives)))
    <> "}"

instance Display (Early Resolved) where
  display Early{..} = display expression <> "?"

instance Display (Boundary Resolved) where
  display Boundary{..} = "early { " <> display expression <> " }"

instance Display (If Resolved) where
  display If {..} =
    "if " <> display condition <> " then " <> display consequent <> " else " <>
    display alternative <>
    "}"

instance Display (Alternative Resolved) where
  display Alternative {..} =
    case pattern' of
      ParamPattern _param ->
        "_" -- TODO: need to resolve from mappings.
         <>
        ": " <>
        display expression
      VariantPattern variant -> display variant <> ": " <> display expression

instance Display (VariantP Resolved) where
  display VariantP {..} =
    display tag <>
    (case argument of
       Nothing -> mempty
       Just _param -> "(_)") -- TODO: need to resolve from mappings.

instance Display (Hole Resolved) where
  display (Hole{}) = "_"

instance Display (Prop Resolved) where
  display (Prop {expression, name}) =
    display expression <> "." <> display name -- TODO: Manage parens.

instance Display (Array Resolved) where
  display (Array {expressions}) =
    "[" <> mconcat (intersperse ", " (map display (toList expressions))) <> "]"

instance Display (Variant Resolved) where
  display (Variant {tag, argument}) =
    display tag <> (if not (null argument)
                       then "(" <> mconcat (intersperse ", " (map display (toList argument))) <> ")"
                       else mempty)

instance Display TagName where
  display (TagName s) ="#" <> display s

instance Display (Record Resolved) where
  display (Record {fields}) =
    "{" <>
    mconcat
      (intersperse
         ", "
         (map
            (\FieldE {name, expression} ->
               display name <> ": " <> display expression)
            fields)) <>
    "}"

instance Display (Infix Resolved) where
  display (Infix {left, global, right}) =
    "(" <> display left <> " " <> display global <> " " <> display right <> ")"

instance Display (Let Resolved) where
  display (Let {body}) = "let ... in " <> display body

instance Display (Literal Resolved) where
  display = \case
               NumberLiteral number -> display number
               TextLiteral LiteralText{text} -> displayBytesUtf8 (L.toStrict (encode text))

instance Display (Number Resolved) where
  display (Number {number}) = display number

instance Display (Lambda Resolved) where
  display Lambda{location,body} =
    case location of
      ImplicitArgumentFor {} -> display body
      _ -> ":" <> display body

instance Display (Variable Resolved) where
  display Variable{name} = "$" <> displayShow (coerce (deBrujinIndexNesting name) :: Int)

instance Display (Global Resolved) where
  display Global{name} = display name

instance Display (GlobalRef Resolved) where
  display = \case
               HashGlobal (Hash hash) -> "#" <> displayShow hash
               FromIntegerGlobal -> "fromInteger"
               FromDecimalGlobal -> "fromDecimal"
               EqualGlobal equality -> case equality of
                                         Equal -> "="
                                         NotEqual -> "/="
               CompareGlobal compareity -> case compareity of
                                         LessThan -> "<"
                                         GreaterThan -> ">"
                                         GreaterEqualTo -> ">="
                                         LessEqualTo -> "="
               NumericBinOpGlobal op -> display op
               InstanceGlobal r -> display r
               FunctionGlobal function -> "@prim:" <> display function

instance Display (Apply Resolved) where
  display apply@Apply {function, argument} =
    case expressionLocation argument of
      ImplicitArgumentFor {} -> display function
      AutoInsertedForDefaulterCursor {} -> display function
      -- TODO: Hides the implicit function applications generated by the
      -- renamer. This isn't very clean. But it requires more thought to
      -- handle this.
      _ ->

        case apply of
          Apply { function = GlobalExpression Global {name = FromDecimalGlobal}
                , argument = LiteralExpression {}
                } -> display argument
          Apply { function = GlobalExpression Global {name = FromIntegerGlobal}
                , argument = LiteralExpression {}
                } -> display argument
          _ -> displayApplyResolved apply

--------------------------------------------------------------------------------
-- Renamed

instance Display (Variant Renamed) where
  display (Variant {tag, argument}) =
    display tag <>
    (if not (null argument)
       then "(" <> mconcat (intersperse ", " (map display (toList argument))) <>
            ")"
       else mempty)

instance Display (Expression Renamed) where
  display =
    \case
      RecordExpression record -> display record
      BoundaryExpression boundary' -> display boundary'
      EarlyExpression early' -> display early'
      IfExpression if' -> display if'
      CaseExpression case' -> display case'
      VariantExpression variant -> display variant
      PropExpression prop -> display prop
      HoleExpression hole -> display hole
      ArrayExpression array -> display array
      LiteralExpression literal -> display literal
      LambdaExpression lambda -> display lambda
      ApplyExpression apply -> display apply
      VariableExpression variable -> display variable
      GlobalExpression global -> display global
      LetExpression let' -> display let'
      InfixExpression infix' -> display infix'

instance Display (Early Renamed) where
  display Early{..} = display expression <> "?"

instance Display (Boundary Renamed) where
  display Boundary{..} = "early { " <> display expression <> " }"

instance Display (Case Renamed) where
  display Case{..} = "case " <> display scrutinee <> " {" <>
    mconcat (intersperse ", " (map display (toList alternatives)))
    <> "}"

instance Display (If Renamed) where
  display If {..} =
    "if " <> display condition <> " then " <> display consequent <> " else " <>
    display alternative <>
    "}"

instance Display (Alternative Renamed) where
  display Alternative {..} =
    case pattern' of
      ParamPattern _param ->
        "_" -- TODO: need to resolve from mappings.
         <>
        ": " <>
        display expression
      VariantPattern variant -> display variant <> ": " <> display expression

instance Display (VariantP Renamed) where
  display VariantP {..} =
    display tag <>
    (case argument of
       Nothing -> mempty
       Just _param -> "(_)") -- TODO: need to resolve from mappings.

instance Display (Hole Renamed) where
  display (Hole{}) = "_"

instance Display (Prop Renamed) where
  display (Prop {expression, name}) =
    display expression <> "." <> display name -- TODO: Manage parens.

instance Display (Array Renamed) where
  display (Array {expressions}) =
    "[" <> mconcat (intersperse ", " (map display (toList expressions))) <> "]"

instance Display (Record Renamed) where
  display (Record {fields}) =
    "{" <>
    mconcat
      (intersperse
         ", "
         (map
            (\FieldE {name, expression} ->
               display name <> ": " <> display expression)
            fields)) <>
    "}"

instance Display (Infix Renamed) where
  display (Infix {left, global, right}) =
    "(" <> display left <> " " <> display global <> " " <> display right <> ")"

instance Display (Let Renamed) where
  display (Let {body}) = "let ... in " <> display body

instance Display (Literal Renamed) where
  display = \case
               NumberLiteral number -> display number
               TextLiteral LiteralText{text} -> displayBytesUtf8 (L.toStrict (encode text))

instance Display (Number Renamed) where
  display (Number {number}) = display number

instance Display (Lambda Renamed) where
  display Lambda{param=_,body} = "(:" <> display body <> ")"

instance Display (Variable Renamed) where
  display Variable{name} = "$" <> displayShow (coerce (deBrujinIndexNesting name) :: Int)

instance Display (Global Renamed) where
  display Global{name} = display name

instance Display (GlobalRef Renamed) where
  display = \case
               HashGlobal (Hash hash) -> "#" <> displayShow hash
               FromIntegerGlobal -> "fromInteger"
               FromDecimalGlobal -> "fromDecimal"
               CompareGlobal compareity -> case compareity of
                                         LessThan -> "<"
                                         GreaterThan -> ">"
                                         GreaterEqualTo -> ">="
                                         LessEqualTo -> "<="
               EqualGlobal equality -> case equality of
                                         Equal -> "="
                                         NotEqual -> "/="
               NumericBinOpGlobal op -> display op
               FunctionGlobal function -> "@prim:" <> display function

instance Display InstanceName where
  display =
    \case
      EqualIntegerInstance -> "<Equal Integer>"
      EqualTextInstance -> "<Equal Text>"
      EqualDecimalInstance n -> "<Equal (Decimal " <> displayShow n <> ")>"
      CompareIntegerInstance -> "<Compare Integer>"
      CompareTextInstance -> "<Compare Text>"
      CompareDecimalInstance n -> "<Compare (Decimal " <> displayShow n <> ")>"
      FromIntegerIntegerInstance -> "<FromInteger Integer>"
      FromIntegerDecimalInstance {} -> "<FromInteger Decimal>"
      FromDecimalDecimalInstance FromDecimalInstance { supersetPlaces
                                                     , subsetPlaces
                                                     } ->
        "<FromDecimal " <> displayShow supersetPlaces <> " (Decimal " <>
        displayShow subsetPlaces <>
        ")>"
      IntegerOpInstance op -> "<(" <> display op <> ") @ Integer>"
      DecimalOpInstance nat op ->
        "<(" <> display op <> ") @(Decimal " <>
        display (fromIntegral nat :: Integer) <>
        ")>"

-- TODO: Hides the implicit function applications generated by the
-- renamer. This isn't very clean. But it requires more thought to
-- handle this.
instance Display (Apply Renamed) where
  display apply@Apply {location, argument} =
    case location of
      AutogeneratedCursor -> display argument
      _ -> case apply of
             Apply { function = GlobalExpression Global {name = ExactGlobalRef FromIntegerGlobal}
                   , argument = LiteralExpression {}
                   } -> display argument
             Apply { function = GlobalExpression Global {name = ExactGlobalRef FromDecimalGlobal}
                   , argument = LiteralExpression {}
                   } -> display argument
             _ -> displayApply display apply

--------------------------------------------------------------------------------
-- Parsed

instance Display (Variant Parsed) where
  display (Variant {tag, argument}) =
    display tag <> (if not (null argument)
                       then "(" <> mconcat (intersperse ", " (map display (toList argument))) <> ")"
                       else mempty)

instance Display (Expression Parsed) where
  display =
    \case
      RecordExpression record -> display record
      BoundaryExpression boundary' -> display boundary'
      EarlyExpression early' -> display early'
      IfExpression if' -> display if'
      CaseExpression case' -> display case'
      VariantExpression variant -> display variant
      PropExpression prop -> display prop
      HoleExpression hole -> display hole
      ArrayExpression array -> display array
      LiteralExpression literal -> display literal
      LambdaExpression lambda -> display lambda
      ApplyExpression apply -> display apply
      VariableExpression variable -> display variable
      GlobalExpression global -> display global
      LetExpression let' -> display let'
      InfixExpression infix' -> display infix'

instance Display (Early Parsed) where
  display Early{..} = display expression <> "?"

instance Display (Boundary Parsed) where
  display Boundary{..} = "early { " <> display expression <> " }"

instance Display (Case Parsed) where
  display Case{..} = "case " <> display scrutinee <> " {" <>
    mconcat (intersperse ", " (map display (toList alternatives)))
    <> "}"

instance Display (If Parsed) where
  display If {..} =
    "if " <> display condition <> " then " <> display consequent <> " else " <>
    display alternative <>
    "}"

instance Display (Alternative Parsed) where
  display Alternative {..} =
    case pattern' of
      ParamPattern param ->
        display param
         <>
        ": " <>
        display expression
      VariantPattern variant -> display variant <> ": " <> display expression

instance Display (VariantP Parsed) where
  display VariantP {..} =
    display tag <>
    (case argument of
       Nothing -> mempty
       Just param -> "(" <> display param <> ")")

instance Display (Hole Parsed) where
  display (Hole{}) = "_"

instance Display (Prop Parsed) where
  display (Prop {expression, name}) =
    display expression <> "." <> display name -- TODO: Manage parens.

instance Display (Array Parsed) where
  display (Array {expressions, typ}) =
    addColumnsIfNeeded expressions typ ("[" <> mconcat (intersperse ", " (map display (toList expressions))) <> "]")

addColumnsIfNeeded :: Display a => Vector e -> Maybe a -> Utf8Builder -> Utf8Builder
addColumnsIfNeeded expressions typ inner =
  case typ of
    Just t | V.null expressions -> inner <> " :: " <> display t
    _ -> inner

instance Display (Type Parsed) where
  display =
    \case
      ArrayType t -> "[" <> display t <> "]"
      RecordType (RowType (TypeRow {fields})) ->
        "{" <>
        mconcat
          (intersperse
             ", "
             (map
                (\Field {name, typ} ->
                   display name <>
                   (case typ of
                      FreshType {} -> ""
                      t -> ":" <> display t))
                fields)) <>
        "}"
      _ -> "_"

instance Display (Record Parsed) where
  display (Record {fields}) =
    "{" <>
    mconcat
      (intersperse
         ", "
         (map
            (\FieldE {name, expression} ->
               display name <> ": " <> display expression)
            fields)) <>
    "}"

-- TODO: Make much more robust.
instance Display FieldName where
  display (FieldName t) =
    if True -- Applying this for graph support. TODO: remove it.
            || T.any (not . printableNameChar) t
      then displayBytesUtf8 (L.toStrict (encode t))
      else display t

printableNameChar :: Char -> Bool
printableNameChar '_' = True
printableNameChar c = isAlphaNum c

instance Display (Infix Parsed) where
  display (Infix {left, global, right}) =
    "(" <> display left <> " " <> display global <> " " <> display right <> ")"

instance Display (Let Parsed) where
  display (Let {body}) = "let ... in " <> display body

instance Display (Literal Parsed) where
  display = \case
               NumberLiteral number -> display number
               TextLiteral LiteralText{text} -> displayBytesUtf8 (L.toStrict (encode text))

instance Display (Number Parsed) where
  display (Number {number}) = display number

instance Display SomeNumber where
  display = \case
               IntegerNumber i -> display i
               DecimalNumber decimal -> display decimal

instance Display Decimal where
  display decimal =
    case decimalToFixed decimal of
      SomeFixed _ f -> displayShow f

instance Display (Lambda Parsed) where
  display Lambda{param,body} = "(" <> display param <> ":" <> display body <> ")"

instance Display (Param Parsed) where
  display Param{name} = display name

instance Display (Variable Parsed) where
  display Variable{name} = display name

instance Display (Global Parsed) where
  display Global{name} = display name

instance Display IncompleteGlobalRef where
  display =
    \case
      UnresolvedGlobalText text -> display text
      UnresolvedUuid (Uuid uuid) -> display uuid
      ExactGlobalRef ref -> display ref
      ResolvedGlobalRef text _ -> display text

instance Display ParsedGlobal where
  display = \case
               ParsedTextName name -> display name
               ParsedHash (Hash hash) -> "#" <> display (sha512AsHexText hash)
               ParsedUuid (Uuid uuid) -> display uuid
               ParsedPrim fun -> "@prim:" <> display fun

instance Display (GlobalRef Parsed) where
  display =
    \case
      HashGlobal (Hash hash) -> "#" <> displayShow hash
      FromIntegerGlobal -> "fromInteger"
      FromDecimalGlobal -> "fromDecimal"
      CompareGlobal compareity ->
        case compareity of
          LessThan -> "<"
          GreaterThan -> ">"
          GreaterEqualTo -> ">="
          LessEqualTo -> "<="
      EqualGlobal equality ->
        case equality of
          Equal -> "="
          NotEqual -> "/="
      NumericBinOpGlobal op -> display op
      FunctionGlobal function -> "@prim:" <> display function

instance Display Function where
  display =
    \case
      MapFunction -> "array_map"
      FromOkFunction -> "from_ok"
      VegaFunction -> "vega"
      FilterFunction -> "array_filter"
      DistinctFunction -> "array_distinct"
      SortFunction -> "array_sort"
      AndFunction -> "array_and"
      OrFunction -> "array_or"
      SumFunction -> "array_sum"
      MinimumFunction -> "array_minimum"
      MaximumFunction -> "array_maximum"
      AverageFunction -> "array_average"
      LengthFunction -> "array_length"
      FindFunction -> "array_find"
      AllFunction -> "array_all"
      AnyFunction -> "array_any"
      NullFunction -> "array_null"

instance Display NumericBinOp where
  display =
    \case
      MulitplyOp -> "*"
      AddOp -> "+"
      SubtractOp -> "-"
      DivideOp -> "/"

instance Display (Apply Parsed) where
  display  = displayApply display

displayApply :: (Expression s -> Utf8Builder) -> Apply s -> Utf8Builder
displayApply display' apply =
  display' function <> "(" <>
  mconcat (intersperse ", " (map display' arguments)) <>
  ")"
  where (function, arguments) = uncurryApplies apply

displayApplyResolved :: Apply Resolved -> Utf8Builder
displayApplyResolved apply =
  display function <> "(" <>
  mconcat (intersperse ", " (map display arguments)) <>
  ")"
  where (function, arguments0) = uncurryApplies apply
        arguments = filter (\e -> case expressionLocation e of
                                    ImplicitArgumentFor{} -> False
                                    _ -> True) arguments0

uncurryApplies :: Apply s -> (Expression s, [Expression s])
uncurryApplies Apply {function, argument} =
  case function of
    ApplyExpression apply ->
      let !(!actualFunction, !arguments) = uncurryApplies apply
      in (actualFunction, arguments <> [argument])
    actualFunction -> (actualFunction, [argument])
