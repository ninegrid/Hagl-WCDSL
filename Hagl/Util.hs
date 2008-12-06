module Game.Util where

import Control.Monad.State
import Data.List

-- TODO: Organize this file, figure out what's needed where, etc.

update :: MonadState s m => (s -> s) -> m s
update f = modify f >> get

--------------------
-- List Functions --
--------------------

expandDist :: [(Int, a)] -> [a]
expandDist d = concat [replicate i a | (i, a) <- d]

branch :: [(Int, a)] -> Int -> Int
branch ((i, _):r) n | n < i = 1
                    | otherwise = 1 + branch r (n-i)

allCombs :: [[a]] -> [[a]]
allCombs (xs:xss) = [(y:ys) | y <- xs, ys <- allCombs xss]
allCombs [] = [[]]

allUnique :: (Ord a) => [[a]] -> [[a]]
allUnique = nub . map sort . allCombs

-- A list indexing function that returns the element at n, or the last
-- element if n is greater than the length of the list.  Works with 
-- infinite lists.
(!!!) :: [a] -> Int -> a
_     !!! n | n < 0 = error "Negative index passed to (!!!)."
(h:_) !!! 0 = h
[a]   !!! _ = a
(_:t) !!! n = t !!! (n-1)

-- Break a list into n equal-sized chunks.
chunk :: Int -> [a] -> [[a]]
chunk _ [] = []
chunk n l = (take n l) : chunk n (drop n l)