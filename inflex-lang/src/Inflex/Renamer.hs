{-# LANGUAGE TupleSections #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}

-- | Renamer for Inflex language.

module Inflex.Renamer
  ( renameText
  , IsRenamed(..)
  , RenameError(..)
  , ParseRenameError(..)
  ) where

import           Control.Monad.State
import           Control.Monad.Validate
import           Data.Bifunctor
import           Data.Foldable
import           Data.List
import qualified Data.List.NonEmpty as NE
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import           Data.Text (Text)
import           Inflex.Instances ()
import           Inflex.Parser
import           Inflex.Types
import           Inflex.Types.Renamer
import           Optics

--------------------------------------------------------------------------------
-- Top-level

renameText ::
     FilePath
  -> Text
  -> Either ParseRenameError (IsRenamed (Expression Renamed))
renameText fp text = do
  expression <- first ParserErrored (parseText fp text)
  first
    RenamerErrors
    (let (result, mappings) =
           runState
             (runValidateT
                (runRenamer
                   (renameExpression
                      (Env {globals = wiredInGlobals, cursor = id, scope = mempty})
                      expression)))
             mempty
      in fmap (\thing -> IsRenamed {thing, mappings}) result)

--------------------------------------------------------------------------------
-- Wired-in

wiredInGlobals :: Map Text (GlobalRef Renamed)
wiredInGlobals =
  M.fromList
    [("fromInteger", FromIntegerGlobal), ("fromDecimal", FromDecimalGlobal)]

--------------------------------------------------------------------------------
-- Renamers

renameExpression :: Env -> Expression Parsed -> Renamer (Expression Renamed)
renameExpression env =
  \case
    LiteralExpression literal ->
      fmap LiteralExpression (renameLiteral env literal)
    LambdaExpression lambda -> fmap LambdaExpression (renameLambda env lambda)
    LetExpression let' -> fmap LetExpression (renameLet env let')
    InfixExpression infix' -> fmap InfixExpression (renameInfix env infix')
    ApplyExpression apply -> fmap ApplyExpression (renameApply env apply)
    VariableExpression variable -> renameVariable env variable
    GlobalExpression{} -> error "impossible" -- TODO: Make impossible at type-level.

renameLiteral :: Env -> Literal Parsed -> Renamer (Literal Renamed)
renameLiteral env =
  \case
    NumberLiteral number -> fmap NumberLiteral (renameNumber env number)

renameNumber :: Env -> Number Parsed -> Renamer (Number Renamed)
renameNumber env@Env{cursor} Number {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  typ' <- renameSignature env typ
  pure Number {location = final, typ=typ', ..}

renameLambda :: Env -> Lambda Parsed -> Renamer (Lambda Renamed)
renameLambda env@Env {cursor} Lambda {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  param' <- renameParam env param
  body' <-
    renameExpression
      (over
         envScopeL
         (LambdaBinding param :)
         (over envCursorL (. LambdaBodyCursor) env))
      body
  typ' <- renameSignature env typ
  pure Lambda {body = body', location = final, param = param', typ = typ', ..}

-- TODO: Disable duplicate names in bind list.
renameLet :: Env -> Let Parsed -> Renamer (Let Renamed)
renameLet env@Env {cursor} Let {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  binds' <-
    traverse
      (\(index, bind) ->
         renameBind
           (over
              envScopeL
              (LetBinding (fmap (\Bind {param} -> param) binds) :)
              (over envCursorL (. LetBindCursor (IndexInLet index)) env))
           bind)
      (NE.zip (NE.fromList [0 ..]) binds)
  body' <-
    renameExpression
      (over
         envScopeL
         (LetBinding (fmap (\Bind {param} -> param) binds) :)
         (over envCursorL (. LetBodyCursor) env))
      body
  typ' <- renameSignature env typ
  pure Let {body = body', location = final, binds = binds', typ = typ', ..}

renameInfix :: Env -> Infix Parsed -> Renamer (Infix Renamed)
renameInfix env@Env {cursor} Infix {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  global' <- renameGlobal (over envCursorL (. InfixOpCursor) env) global
  left' <- renameExpression (over envCursorL (. InfixLeftCursor) env) left
  right' <- renameExpression (over envCursorL (. InfixRightCursor) env) right
  typ' <- renameSignature env typ
  pure
    Infix
      { left = left'
      , global = global'
      , right = right'
      , location = final
      , typ = typ'
      , ..
      }

renameGlobal :: Env -> Global Parsed -> Renamer (Global Renamed)
renameGlobal Env {cursor} Global {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  let op = pure . NumericBinOpGlobal
  name' <-
    case name of
      "*" -> op MulitplyOp
      "+" -> op AddOp
      "-" -> op SubtractOp
      "/" -> op DivideOp
      _ -> Renamer (refute (pure (UnknownOperatorName name)))
  pure Global {location = final, scheme = RenamedScheme, name = name'}

renameBind :: Env -> Bind Parsed -> Renamer (Bind Renamed)
renameBind env@Env {cursor} Bind {param, value, location, typ} = do
  final <- finalizeCursor cursor ExpressionCursor location
  param' <- renameParam env param
  value' <- renameExpression env value
  typ' <- renameSignature env typ
  pure Bind {value = value', param = param', location = final, typ = typ'}

renameApply :: Env -> Apply Parsed -> Renamer (Apply Renamed)
renameApply env@Env {cursor} Apply {..} = do
  function' <-
    renameExpression (over envCursorL (. ApplyFuncCursor) env) function
  argument' <-
    renameExpression (over envCursorL (. ApplyArgCursor) env) argument
  final <- finalizeCursor cursor ExpressionCursor location
  typ' <- renameSignature env typ
  pure Apply {function = function', argument = argument', location = final, typ = typ'}

renameVariable ::
     Env
  -> Variable Parsed
  -> Renamer (Expression Renamed)
renameVariable env@Env {scope, cursor, globals} variable@Variable { name
                                                                  , location
                                                                  , typ
                                                                  } =
  case find
         (any (\Param {name = name'} -> name' == name) . bindingParam . snd)
         (zip [0 ..] scope) of
    Nothing ->
      case M.lookup name globals of
        Nothing ->
          Renamer (refute (pure (MissingVariable scope globals variable)))
        Just globalRef -> do
          final <- finalizeCursor cursor ExpressionCursor location
          pure
            (GlobalExpression
               (Global
                  {location = final, name = globalRef, scheme = RenamedScheme}))
    Just (index, binding) -> do
      final <- finalizeCursor cursor ExpressionCursor location
      typ' <- renameSignature env typ
      deBrujinIndex <-
        case binding of
          LambdaBinding {} -> pure (DeBrujinIndex (DeBrujinNesting index))
          LetBinding params ->
            case findIndex
                   (\Param {name = name'} -> name' == name)
                   (toList params) of
              Nothing ->
                Renamer (refute (pure (MissingVariable scope globals variable)))
              Just subIndex ->
                pure
                  (DeBrujinIndexOfLet
                     (DeBrujinNesting index)
                     (IndexInLet subIndex))
      pure
        (VariableExpression
           (Variable {location = final, name = deBrujinIndex, typ = typ'}))

renameParam :: Env -> Param Parsed -> Renamer (Param Renamed)
renameParam env@Env{cursor} Param {..} = do
  final <- finalizeCursor cursor LambdaParamCursor location
  typ' <- renameSignature env typ
  pure Param {name = (), location = final, typ = typ'}

renameSignature :: Env -> Maybe (Type Parsed) -> Renamer (Maybe (Type Renamed))
renameSignature env =
  maybe
    (pure Nothing)
    (fmap Just . renameType (over envCursorL (. SignatureCursor) env))

renameType :: Env -> Type Parsed -> Renamer (Type Renamed)
renameType env =
  \case
    VariableType typeVariable ->
      fmap VariableType (renameTypeVariable env typeVariable)
    ApplyType typeApplication ->
      fmap ApplyType (renameTypeApplication env typeApplication)
    ConstantType typeConstant ->
      fmap ConstantType (renameTypeConstant env typeConstant)

renameTypeConstant :: Env -> TypeConstant Parsed -> Renamer (TypeConstant Renamed)
renameTypeConstant Env{cursor} TypeConstant {..} = do
  final <- finalizeCursor cursor TypeCursor location
  pure TypeConstant {location = final, ..}

renameTypeApplication :: Env -> TypeApplication Parsed -> Renamer (TypeApplication Renamed)
renameTypeApplication env@Env {cursor} TypeApplication {function, argument, ..} = do
  function' <- renameType (over envCursorL (. TypeApplyCursor) env) function
  argument' <- renameType (over envCursorL (. TypeApplyCursor) env) argument
  final <- finalizeCursor cursor TypeCursor location
  pure
    TypeApplication
      {function = function', argument = argument', location = final, ..}

renameTypeVariable :: Env -> TypeVariable Parsed -> Renamer (TypeVariable Renamed)
renameTypeVariable Env{cursor} TypeVariable {..} = do
  final <- finalizeCursor cursor TypeCursor location
  pure TypeVariable {location = final, ..}

--------------------------------------------------------------------------------
-- Cursor operations

finalizeCursor :: CursorBuilder -> Cursor -> StagedLocation Parsed -> Renamer Cursor
finalizeCursor cursor finalCursor loc = do
  modify (M.insert final loc)
  pure final
  where final = cursor finalCursor
