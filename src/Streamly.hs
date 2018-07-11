-- |
-- Module      : Streamly
-- Copyright   : (c) 2017 Harendra Kumar
--
-- License     : BSD3
-- Maintainer  : harendra.kumar@gmail.com
-- Stability   : experimental
-- Portability : GHC
--
-- The way a list represents a sequence of pure values, a stream represents a
-- sequence of monadic actions. The monadic stream API offered by Streamly is
-- very close to the Haskell "Prelude" pure lists' API, it can be considered as
-- a natural extension of lists to monadic actions. Streamly streams provide
-- concurrent composition and merging of streams. It can be considered as a
-- concurrent list transformer. In contrast to the "Prelude" lists, merging or
-- appending streams of arbitrary length is scalable and inexpensive.
--
-- The basic stream type is 'Serial', it represents a sequence of IO actions,
-- and is a 'Monad'.  The type 'SerialT' is a monad transformer that can
-- represent a sequence of actions in an arbitrary monad. The type 'Serial' is
-- in fact a synonym for @SerialT IO@.  There are a few more types similar to
-- 'SerialT', all of them represent a stream and differ only in the
-- 'Semigroup', 'Applicative' and 'Monad' compositions of the stream. 'Serial'
-- and 'WSerial' types compose serially whereas 'Async' and 'WAsync'
-- types compose concurrently. All these types can be freely inter-converted
-- using type combinators without any cost. You can freely switch to any type
-- of composition at any point in the program.  When no type annotation or
-- explicit stream type combinators are used, the default stream type is
-- inferred as 'Serial'.
--
-- Here is a simple console echo program example:
--
-- @
-- > runStream $ S.repeatM getLine & S.mapM putStrLn
-- @
--
-- For more details please see the "Streamly.Tutorial" module and the examples
-- directory in this package.
--
-- This module exports stream types, instances and some basic operations.
-- Functionality exported by this module include:
--
-- * Semigroup append ('<>') instances as well as explicit  operations for merging streams
-- * Monad and Applicative instances for looping over streams
-- * Zip Applicatives for zipping streams
-- * Stream type combinators to convert between different composition styles
-- * Some basic utilities to run and fold streams
--
-- See the "Streamly.Prelude" module for comprehensive APIs for construction,
-- generation, elimination and transformation of streams.
--
-- This module is designed to be imported unqualified:
--
-- @
-- import Streamly
-- @

module Streamly
    (
      MonadAsync

    -- * Stream transformers
    -- ** Serial Streams
    -- $serial
    , SerialT
    , WSerialT

    -- ** Concurrent Lookahead Streams
    -- $lookahead
    , AheadT

    -- ** Concurrent Asynchronous Streams
    -- $async
    , AsyncT
    , WAsyncT
    , ParallelT

    -- ** Zipping Streams
    -- $zipping
    , ZipSerialM
    , ZipAsyncM

    -- * Running Streams
    , runStream

    -- * Parallel Function Application
    -- $application
    , (|$)
    , (|&)
    , (|$.)
    , (|&.)
    , mkAsync

    -- * Merging Streams
    -- $sum
    , serial
    , wSerial
    , ahead
    , async
    , wAsync
    , parallel

    -- * Concurrency Control
    -- $concurrency
    , maxThreads
    , maxBuffer

    -- * Folding Containers of Streams
    -- $foldutils
    , foldWith
    , foldMapWith
    , forEachWith

    -- * Stream Type Adapters
    -- $adapters
    , IsStream ()

    , serially
    , wSerially
    , asyncly
    , aheadly
    , wAsyncly
    , parallely
    , zipSerially
    , zipAsyncly
    , adapt

    -- * IO Streams
    , Serial
    , WSerial
    , Ahead
    , Async
    , WAsync
    , Parallel
    , ZipSerial
    , ZipAsync

    -- * Re-exports
    , Semigroup (..)
    -- * Deprecated
    , Streaming
    , runStreaming
    , runStreamT
    , runInterleavedT
    , runAsyncT
    , runParallelT
    , runZipStream
    , runZipAsync
    , StreamT
    , InterleavedT
    , ZipStream
    , interleaving
    , zipping
    , zippingAsync
    , (<=>)
    , (<|)
    )
where

import Streamly.Streams.StreamK hiding (runStream, serial)
import Streamly.Streams.Serial
import Streamly.Streams.Async
import Streamly.Streams.Ahead
import Streamly.Streams.Parallel
import Streamly.Streams.Zip
import Streamly.Streams.Prelude
import Streamly.Streams.SVar (maxThreads, maxBuffer)
import Streamly.SVar (MonadAsync)
import Data.Semigroup (Semigroup(..))

-- $serial
--
-- Serial streams compose serially or non-concurrently. In a composed stream,
-- each action is executed only after the previous action has finished.  The two
-- serial stream types 'SerialT' and 'WSerialT' differ in how they traverse the
-- streams in a 'Semigroup' or 'Monad' composition.

-- $async
--
-- The async style streams execute actions asynchronously and consume the
-- outputs as well asynchronously. In a composed stream, at any point of time
-- more than one stream can run concurrently and yield elements.  The elements
-- are yielded by the composed stream as they are generated by the constituent
-- streams on a first come first serve basis.  Therefore, on each run the
-- stream may yield elements in a different sequence depending on the delays
-- introduced by scheduling.  The two async types 'AsyncT' and 'WAsyncT' differ
-- in how they traverse streams in 'Semigroup' or 'Monad' compositions.

-- $zipping
--
-- 'ZipSerialM' and 'ZipAsyncM', provide 'Applicative' instances for zipping the
-- corresponding elements of two streams together. Note that these types are
-- not monads.

-- $application
--
-- Stream processing functions can be composed in a chain using function
-- application with or without the '$' operator, or with reverse function
-- application operator '&'. Streamly provides concurrent versions of these
-- operators applying stream processing functions such that each stage of the
-- stream can run in parallel. The operators start with a @|@; we can read '|$'
-- as "@parallel dollar@" to remember that @|@ comes before '$'.
--
-- Imports for the code snippets below:
--
-- @
--  import Streamly
--  import qualified Streamly.Prelude as S
--  import Control.Concurrent
-- @

-- $sum
-- The 'Semigroup' operation '<>' of each stream type combines two streams in a
-- type specific manner. This section provides polymorphic versions of '<>'
-- which can be used to combine two streams in a predetermined way irrespective
-- of the type.

-- $concurrency
--
-- These combinators can be used at any point in a stream composition to
-- control the concurrency of the enclosed stream. When the combinators are
-- used in a nested manner, the nearest enclosing combinator overrides the
-- outer ones.  These combinators have no effect on 'Parallel' streams,
-- concurrency for 'Parallel' streams is always unbounded.
-- Note that the use of these combinators does not enable concurrency, to
-- enable concurrency you have to use one of the concurrent stream type
-- combinators.

-- $adapters
--
-- You may want to use different stream composition styles at different points
-- in your program. Stream types can be freely converted or adapted from one
-- type to another.  The 'IsStream' type class facilitates type conversion of
-- one stream type to another. It is not used directly, instead the type
-- combinators provided below are used for conversions.
--
-- To adapt from one monomorphic type (e.g. 'AsyncT') to another monomorphic
-- type (e.g. 'SerialT') use the 'adapt' combinator. To give a polymorphic code
-- a specific interpretation or to adapt a specific type to a polymorphic type
-- use the type specific combinators e.g. 'asyncly' or 'wSerially'. You
-- cannot adapt polymorphic code to polymorphic code, as the compiler would not know
-- which specific type you are converting from or to. If you see a an
-- @ambiguous type variable@ error then most likely you are using 'adapt'
-- unnecessarily on polymorphic code.
--

-- $foldutils
--
-- These are variants of standard 'Foldable' fold functions that use a
-- polymorphic stream sum operation (e.g. 'async' or 'wSerial') to fold a
-- container of streams.
