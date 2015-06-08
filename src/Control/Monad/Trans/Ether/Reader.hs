{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Control.Monad.Trans.Ether.Reader
    ( EtherReaderT
    , EtherReader
    , ReaderT'
    , Reader'
    , runEtherReaderT
    , runEtherReader
    , runReaderT'
    , runReader'
    --
    , etherReaderT
    , mapEtherReaderT
    , liftCatch
    , liftCallCC
    ) where

import Data.Proxy (Proxy(Proxy))
import Data.Functor.Identity (Identity(..))
import Data.Coerce (coerce)
import Control.Applicative (Alternative)
import Control.Monad (MonadPlus)
import Control.Monad.Fix (MonadFix)
import Control.Monad.Trans.Class (MonadTrans, lift)
import Control.Monad.IO.Class (MonadIO)
import Control.Ether.Core

import qualified Control.Monad.Signatures as Sig
import qualified Control.Monad.Trans.Reader as R

import qualified Control.Monad.Cont.Class    as Class
import qualified Control.Monad.Reader.Class  as Class
import qualified Control.Monad.State.Class   as Class
import qualified Control.Monad.Writer.Class  as Class
import qualified Control.Monad.Error.Class   as Class

newtype EtherReaderT tag r m a = EtherReaderT (R.ReaderT r m a)
    deriving ( Functor, Applicative, Alternative, Monad, MonadPlus
             , MonadFix, MonadTrans, MonadIO )

type EtherReader tag r = EtherReaderT tag r Identity

instance Monad m => MonadEther (EtherReaderT tag r m) where
    type EtherTags (EtherReaderT tag r m) = tag ': EtherTags m

etherReaderT :: proxy tag -> (r -> m a) -> EtherReaderT tag r m a
etherReaderT _proxy = EtherReaderT . R.ReaderT

runEtherReaderT :: proxy tag -> EtherReaderT tag r m a -> r -> m a
runEtherReaderT _proxy (EtherReaderT (R.ReaderT s)) = s

runEtherReader :: proxy tag -> EtherReader tag r a -> r -> a
runEtherReader proxy m r = runIdentity (runEtherReaderT proxy m r)

mapEtherReaderT :: proxy tag -> (m a -> n b) -> EtherReaderT tag r m a -> EtherReaderT tag r n b
mapEtherReaderT _proxy f m = EtherReaderT $ R.mapReaderT f (coerce m)

liftCatch :: proxy tag -> Sig.Catch e m a -> Sig.Catch e (EtherReaderT tag r m) a
liftCatch _proxy f m h = EtherReaderT $ R.liftCatch f (coerce m) (coerce h)

liftCallCC :: proxy tag -> Sig.CallCC m a b -> Sig.CallCC (EtherReaderT tag r m) a b
liftCallCC _proxy callCC f = EtherReaderT $ R.liftCallCC callCC (coerce f)

type ReaderT' r = EtherReaderT r r
type Reader' r = EtherReader r r

runReaderT' :: ReaderT' r m a -> r -> m a
runReaderT' = runEtherReaderT Proxy

runReader' :: Reader' r a -> r -> a
runReader' m r = runIdentity (runEtherReaderT Proxy m r)

-- Instances for mtl classes

instance Class.MonadCont m => Class.MonadCont (EtherReaderT tag r m) where
    callCC = liftCallCC Proxy Class.callCC

instance Class.MonadReader r' m => Class.MonadReader r' (EtherReaderT tag r m) where
    ask = lift Class.ask
    local = mapEtherReaderT Proxy . Class.local
    reader = lift . Class.reader

instance Class.MonadState s m => Class.MonadState s (EtherReaderT tag r m) where
    get = lift Class.get
    put = lift . Class.put
    state = lift . Class.state

instance Class.MonadWriter w m => Class.MonadWriter w (EtherReaderT tag r m) where
    writer = lift . Class.writer
    tell   = lift . Class.tell
    listen = mapEtherReaderT Proxy Class.listen
    pass   = mapEtherReaderT Proxy Class.pass

instance Class.MonadError e m => Class.MonadError e (EtherReaderT tag r m) where
    throwError = lift . Class.throwError
    catchError = liftCatch Proxy Class.catchError
