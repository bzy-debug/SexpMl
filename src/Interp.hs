{-# OPTIONS_GHC -Wno-name-shadowing #-}

module Interp where

import Ast
import Control.Monad.Except
import Control.Monad.State
import Convert

newRef :: Env Value -> EvalMonad Ref
newRef env = do
  RefState {mem = mem, ref = ref} <- get
  put $
    RefState
      { mem = (ref, env) : mem,
        ref = ref + 1
      }
  return $ ref + 1

writeRef :: Ref -> Env Value -> EvalMonad ()
writeRef r e = do
  RefState {mem = mem, ref = ref} <- get
  put $ RefState {mem = (r, e) : mem, ref = ref}

readRef :: Ref -> EvalMonad (Env Value)
readRef r = do
  RefState {mem = mem} <- get
  case lookup r mem of
    Nothing -> throwError "undefined"
    Just env -> return env

eval :: Exp -> Env Value -> EvalMonad Value
eval e rho =
  let ev :: Exp -> EvalMonad Value
      ev (Literal v) = return v
      ev (Var x) =
        case lookup x rho of
          Nothing -> throwError "NotFound"
          Just v -> return v
      ev (If cond ifso ifelse) = do
        condVal <- ev cond
        ev $ if projectBool condVal then ifso else ifelse
      ev (Begin exprs) =
        let iter [] lastval = return lastval
            iter (e : es) _ = ev e >>= iter es
         in iter exprs (Bool False)
      ev (Lambda xs body) = do
        ref <- newRef rho
        return $ Closure (xs, body) ref
      ev e@(Apply fun args) = do
        funVal <- ev fun
        case funVal of
          Primitive prim -> do
            vals <- mapM ev args
            prim e vals
          Closure (formals, body) ref -> do
            actuals <- mapM ev args
            if length formals == length actuals
              then do
                savedEnv <- readRef ref
                let extend = zip formals actuals
                eval body (extend ++ savedEnv)
              else throwError "BugInTypeInference"
          _ -> throwError "BugInTypeInference"
      ev (Letx Let bs body) = do
        let (names, exps) = unzip bs
        values <- mapM ev exps
        eval body (zip names values ++ rho)
      ev (Letx LetStar bs body) =
        case bs of
          [] -> ev body
          b : bs -> ev (Letx Let [b] (Letx LetStar bs body))
      ev (Letx LetRec bs body) = do
        newref <- newRef []
        let rho' =
              foldl
                ( \rho (x, e) ->
                    (x, Closure (asLambda e) newref) : rho
                )
                rho
                bs
        _ <- writeRef newref rho'
        eval body rho'
        where
          asLambda :: Exp -> ([Name], Exp)
          asLambda (Lambda formals body) = (formals, body)
          asLambda _ = error "InternalError"
   in ev e

-- eval expr = do
--   s@InterpState {env = curEnv} <- get
--   res <- ev expr
--   put s {env = curEnv}
--   return res
--   where
--     ev (ELiteral val) = return val
--     ev (EVar name) = readBind name
--     ev (ESet name expr) = do
--       val <- ev expr
--       writeBind name val
--       return val
--     ev (EIfx cond ifso ifelse) = do
--       condVal <- ev cond
--       ev $ if projectBool condVal then ifso else ifelse
--     ev (EWhilex guard body) = do
--       guardVal <- ev guard
--       if projectBool guardVal
--         then ev body >> ev (EWhilex guard body)
--         else return $ VBool False
--     ev (EBegin exprs) = iter exprs (VBool False)
--       where
--         iter [] lastVal = return lastVal
--         iter (e : es) _ = ev e >>= iter es
--     ev (ELambda names body) = do
--       InterpState {env = env} <- get
--       return $ VClosure names body env
--     ev (ELetx Let binds body) = do
--       let (names, rhs) = unzip binds
--       vals <- mapM ev rhs
--       zipWithM_ newBind names vals
--       ev body
--     ev (ELetx LetStar binds body) = do
--       forM_
--         binds
--         ( \(name, rhs) -> do
--             val <- ev rhs
--             newBind name val
--         )
--       ev body
--     ev (ELetx LetRec binds body) = do
--       let (names, rhs) = unzip binds
--       mapM_ (`newBind` VNil) names
--       vals <- mapM ev rhs
--       zipWithM_ writeBind names vals
--       ev body

-- testEval :: String -> Except InterpException Value
-- testEval s =
--   case parseMaybe expression s of
--     Nothing -> error "Parse error"
--     Just expr -> evalStateT (eval expr) initState
