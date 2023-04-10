module Constraint where

import Ast
import Data.List
import Subst
import Type

data Constraint
  = Ceq Type Type
  | Cand Constraint Constraint
  | Trival

instance Show Constraint where
  show = show' . untriviate
    where
      show' (Ceq t t') = show t ++ " ~ " ++ show t'
      show' (Cand c c') = show c ++ " /\\ " ++ show c'
      show' Trival = "T"

conjoin :: [Constraint] -> Constraint
conjoin = foldr Cand Trival

untriviate :: Constraint -> Constraint
untriviate (Cand c c') =
  case (untriviate c, untriviate c') of
    (Trival, c) -> c
    (c, Trival) -> c
    (c, c') -> Cand c c'
untriviate atomic = atomic

ftvCons :: Constraint -> [Name]
ftvCons (Ceq t t') = ftv t `union` ftv t'
ftvCons (Cand c c') = ftvCons c `union` ftvCons c'
ftvCons Trival = []

substCons :: Subst -> Constraint -> Constraint
substCons s (Ceq t t') = Ceq (subst s t) (subst s t')
substCons s (Cand c c') = Cand (substCons s c) (substCons s c')
substCons _ Trival = Trival
