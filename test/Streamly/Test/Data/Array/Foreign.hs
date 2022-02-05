-- |
-- Module      : Streamly.Test.Data.Array.Foreign
-- Copyright   : (c) 2019 Composewell technologies
-- License     : BSD-3-Clause
-- Maintainer  : streamly@composewell.com
-- Stability   : experimental
-- Portability : GHC

module Streamly.Test.Data.Array.Foreign (main) where

#include "Streamly/Test/Data/Array/CommonImports.hs"

import Data.Word(Word8)

import qualified Streamly.Internal.Data.Fold as Fold
import qualified Streamly.Internal.Data.Array.Foreign as A
import qualified Streamly.Internal.Data.Array.Foreign.Type as A
import qualified Streamly.Internal.Data.Array.Foreign.Mut.Type as MA
import qualified Streamly.Internal.Data.Array.Stream.Foreign as AS
type Array = A.Array

moduleName :: String
moduleName = "Data.Array.Foreign"

#include "Streamly/Test/Data/Array/Common.hs"

testFromStreamToStream :: Property
testFromStreamToStream = genericTestFromTo (const A.fromStream) A.toStream (==)

testFoldUnfold :: Property
testFoldUnfold = genericTestFromTo (const (S.fold A.write)) (S.unfold A.read) (==)

testFromList :: Property
testFromList =
    forAll (choose (0, maxArrLen)) $ \len ->
            forAll (vectorOf len (arbitrary :: Gen Int)) $ \list ->
                monadicIO $ do
                    let arr = A.fromList list
                    xs <- run $ S.toList $ (S.unfold A.read) arr
                    assert (xs == list)

testLengthFromStream :: Property
testLengthFromStream = genericTestFrom (const A.fromStream)


unsafeWriteIndex :: [Int] -> Int -> Int -> IO Bool
unsafeWriteIndex xs i x = do
    arr <- MA.fromList xs
    MA.putIndexUnsafe i x arr
    x1 <- MA.getIndexUnsafe i arr
    return $ x1 == x

lastN :: Int -> [a] -> [a]
lastN n l = drop (length l - n) l

testLastN :: Property
testLastN =
    forAll (choose (0, maxArrLen)) $ \len ->
        forAll (choose (0, len)) $ \n ->
            forAll (vectorOf len (arbitrary :: Gen Int)) $ \list ->
                monadicIO $ do
                    xs <- run
                        $ fmap A.toList
                        $ S.fold (A.writeLastN n)
                        $ S.fromList list
                    assert (xs == lastN n list)

testLastN_LN :: Int -> Int -> IO Bool
testLastN_LN len n = do
    let list = [1..len]
    l1 <- fmap A.toList $ S.fold (A.writeLastN n) $ S.fromList list
    let l2 = lastN n list
    return $ l1 == l2

-- Instead of hard coding 10000 here we can have maxStreamLength for operations
-- that use stream of arrays.
concatArrayW8 :: Property
concatArrayW8 =
    forAll (vectorOf 10000 (arbitrary :: Gen Word8))
        $ \w8List -> do
              let w8ArrList = A.fromList . (: []) <$> w8List
              f2 <- S.toList $ AS.concat $ S.fromList w8ArrList
              w8List `shouldBe` f2

unsafeSlice :: Int -> Int -> [Int] -> Bool
unsafeSlice i n list =
    let lst = take n $ drop i $ list
        arr = A.toList $ A.getSliceUnsafe i n $ A.fromList list
     in arr == lst

main :: IO ()
main =
    hspec $
    H.parallel $
    modifyMaxSuccess (const maxTestCount) $ do
      describe moduleName $ do
        commonMain
        describe "Construction" $ do
            prop "length . fromStream === n" testLengthFromStream
            prop "toStream . fromStream === id" testFromStreamToStream
            prop "read . write === id" testFoldUnfold
            prop "fromList" testFromList
            prop "foldMany with writeNUnsafe concats to original"
                (foldManyWith (\n -> Fold.take n (A.writeNUnsafe n)))
            prop "AS.concat . (A.fromList . (:[]) <$>) === id" $ concatArrayW8
        describe "unsafeSlice" $ do
            it "partial" $ unsafeSlice 2 4 [1..10]
            it "none" $ unsafeSlice 10 0 [1..10]
            it "full" $ unsafeSlice 0 10 [1..10]
        describe "Mut.unsafeWriteIndex" $ do
            it "first" (unsafeWriteIndex [1..10] 0 0 `shouldReturn` True)
            it "middle" (unsafeWriteIndex [1..10] 5 0 `shouldReturn` True)
            it "last" (unsafeWriteIndex [1..10] 9 0 `shouldReturn` True)
        describe "Fold" $ do
            prop "writeLastN : 0 <= n <= len" $ testLastN
            describe "writeLastN boundary conditions" $ do
                it "writeLastN -1" (testLastN_LN 10 (-1) `shouldReturn` True)
                it "writeLastN 0" (testLastN_LN 10 0 `shouldReturn` True)
                it "writeLastN length" (testLastN_LN 10 10 `shouldReturn` True)
                it "writeLastN (length + 1)" (testLastN_LN 10 11 `shouldReturn` True)
