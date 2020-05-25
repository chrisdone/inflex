{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DeriveFunctor #-}

-- | Type generator for Inflex.

module Inflex.Generator
  ( generateText
  , RenameGenerateError(..)
  , HasConstraints(..)
  ) where

import           Control.Monad.State
import           Control.Monad.Trans.Reader
import           Data.Bifunctor
import           Data.Map.Strict (Map)
import           Data.Sequence (Seq)
import qualified Data.Sequence as Seq
import           Data.Text (Text)
import           Inflex.Instances ()
import           Inflex.Optics
import           Inflex.Renamer
import           Inflex.Type
import           Inflex.Types
import           Optics

--------------------------------------------------------------------------------
-- Types

data GenerateState = GenerateState
  { counter :: !Integer
  , classConstraints :: !(Seq (ClassConstraint Generated))
  , equalityConstraints :: !(Seq EqualityConstraint)
  } deriving (Show)

newtype Generate a = Generate
  { runGenerator :: ReaderT Env (State GenerateState) a
  } deriving (Functor, Applicative, Monad)

data Env = Env
  { scope :: !(Map DeBrujinIndex (Param Parsed))
  }

data RenameGenerateError
  = RenameGenerateError ParseRenameError
  deriving (Show, Eq)

data HasConstraints a = HasConstraints
  { classes :: !(Seq (ClassConstraint Generated))
  , thing :: !a
  , mappings :: !(Map Cursor SourceLocation)
  } deriving (Show, Functor, Eq, Ord)

$(makeLensesWith (inflexRules ['counter, 'classConstraints]) ''GenerateState)

--------------------------------------------------------------------------------
-- Top-level

generateText :: FilePath -> Text -> Either RenameGenerateError (HasConstraints (Expression Generated))
generateText fp text = do
  IsRenamed {thing = expression, mappings} <-
    first RenameGenerateError (renameText fp text)
  pure
    (let (expression', GenerateState {classConstraints = classes}) =
           runState
             (runReaderT
                (runGenerator (expressionGenerator expression))
                (Env {scope = mempty}))
             GenerateState
               { classConstraints = mempty
               , counter = 0
               , equalityConstraints = mempty
               }
      in HasConstraints {classes, thing = expression', mappings})

--------------------------------------------------------------------------------
-- Generators

expressionGenerator :: Expression Renamed -> Generate (Expression Generated)
expressionGenerator =
  \case
    LiteralExpression literal ->
      fmap LiteralExpression (literalGenerator literal)
    LambdaExpression lambda ->
      fmap LambdaExpression (lambdaGenerator lambda)
    ApplyExpression apply ->
      fmap ApplyExpression (applyGenerator apply)
    VariableExpression variable ->
      fmap VariableExpression (variableGenerator variable)

literalGenerator :: Literal Renamed -> Generate (Literal Generated)
literalGenerator =
  \case
    IntegerLiteral integery -> fmap IntegerLiteral (integeryGenerator integery)

integeryGenerator :: Integery Renamed -> Generate (Integery Generated)
integeryGenerator Integery {typ = _, ..} = do
  typ <- generateTypeVariable location IntegeryPrefix
  addClassConstraint
    (ClassConstraint
       {className = FromIntegerClassName, types = pure typ, location})
  pure Integery {typ, ..}

lambdaGenerator :: Lambda Renamed -> Generate (Lambda Generated)
lambdaGenerator Lambda {typ = _, ..} = do
  param' <- paramGenerator param
  body' <- expressionGenerator body
  let outputType = expressionType body'
  pure
    Lambda
      { typ =
          ApplyType
            TypeApplication
              { function =
                  ApplyType
                    TypeApplication
                      { function =
                          ConstantType
                            (TypeConstant {name = FunctionTypeName, location})
                      , argument = paramType param'
                      , location
                      }
              , argument = outputType
              , location
              }
      , body = body'
      , param = param'
      , ..
      }

paramGenerator :: Param Renamed -> Generate (Param Generated)
paramGenerator Param {typ = _, ..} = do
  typ <- generateTypeVariable location LambdaParameterPrefix
  pure Param {typ, ..}

applyGenerator :: Apply Renamed -> Generate (Apply Generated)
applyGenerator Apply {typ = _, ..} = do
  undefined

variableGenerator :: Variable Renamed -> Generate (Variable Generated)
variableGenerator Variable {typ = _, ..} = do
  undefined

--------------------------------------------------------------------------------
-- Type system helpers

generateTypeVariable :: StagedLocation Generated -> TypeVariablePrefix -> Generate (Type Generated)
generateTypeVariable location prefix =
  Generate
    (do index <- gets (view generateStateCounterL)
        modify' (over generateStateCounterL succ)
        pure (VariableType TypeVariable {prefix, index, location}))

addClassConstraint :: ClassConstraint Generated -> Generate ()
addClassConstraint constraint =
  Generate (modify' (over generateStateClassConstraintsL (Seq.|> constraint)))