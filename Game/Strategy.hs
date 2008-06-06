module Game.Strategy where

import Control.Monad.State
import Data.List
import Data.Maybe
import Game.Definition
import Game.Execution
import Game.Execution.Util
import Game.Util

-----------------------
-- Common Strategies --
-----------------------

-- Construct a pure strategy. Always play the same move.
pure :: m -> Strategy m
pure = return

-- Pick a move from the list of available moves randomly.
random :: Strategy m
random = randomFrom =<< liftM availMoves (liftM _location get)

-- Pick a move randomly from a list.
randomFrom :: [m] -> Strategy m
randomFrom as = liftM (as !!) (randomIndex as)

-- Construct a mixed strategy. Play moves based on a distribution.
mixed :: [(Int, m)] -> Strategy m
mixed = randomFrom . expandDist

-- Perform some pattern of moves periodically.
periodic :: [m] -> Strategy m
periodic ms = numGames >>= \n -> return $ ms !! mod n (length ms)

initially :: Strategy m -> [Strategy m] -> Strategy m
initially s ss = numGames >>= \n -> (s:ss) !!! n

next :: Strategy m -> [Strategy m] -> [Strategy m]
next = (:)

finally :: Strategy m -> [Strategy m]
finally = (:[])

-- Perform some strategy on the first move, then another strategy thereafter.
initiallyThen :: Strategy m -> Strategy m -> Strategy m
initiallyThen a b = initially a $ finally b

{-
stateful :: s -> StatefulStrategy s m -> Strategy m
stateful s m = 
  where g s = evalStateT m s : g 

stateful :: s -> (s -> GameExec m (s,m)) -> Strategy m
stateful s f = numGames >>= \n -> (g s) !!! n
  where g s = (do (s', m) <- f s
                  return m) : g s

stateful :: s -> (s -> (s, Strategy m)) -> Strategy m
stateful s f = numGames >>= \n -> (g s) !!! n
  where g s = let (s', m) = f s in m : g s'
-}

-- Minimax algorithm with alpha-beta pruning. Only defined for games with
-- perfect information and no Chance nodes.
minimax = myIndex >>= \me -> location >>= \loc ->
  let isMe = (me + 1 ==)
      val alpha beta n@(Decision p _)
         | alpha >= beta = if isMe p then alpha else beta
         | otherwise =
             let mm (a,b) n = let v = val a b n
                              in if isMe p then (max a v, b)
                                           else (a, min b v)
                 (alpha', beta') = foldl mm (alpha, beta) (children n)
             in if isMe p then alpha' else beta'
      val _ _ (Payoff vs) = vs !! me
  in case loc of
       Imperfect ns -> undefined
       Perfect n -> 
         let vals = map (val (-infinity) infinity) (children n)
         in return $ availMoves n !! maxIndex vals

infinity :: Float
infinity = 1/0

--------------------------
-- History Manipulation --
--------------------------

-- True if this is the first iteration in this execution instance.
isFirstGame :: GameExec m Bool
isFirstGame = liftM (null . asList) history

-- Transcript of each game.
transcripts :: GameExec m (ByGame (Transcript m))
transcripts = liftM (ByGame . fst . unzip . asList) history

-- Summary of each game.
summaries :: GameExec m (ByGame (Summary m))
summaries = liftM (ByGame . snd . unzip . asList) history

-- All moves made by each player in each game.
moves :: GameExec m (ByGame (ByPlayer [m]))
moves = liftM (ByGame . fst . unzip . asList) summaries

-- The last move by each player in each game.
move :: GameExec m (ByGame (ByPlayer m))
move = liftM (ByGame . map (ByPlayer . map head) . asList2) moves

-- The total payoff for each player for each game.
payoff :: GameExec m (ByGame (ByPlayer Float))
payoff = liftM (ByGame . snd . unzip . asList) summaries

-- The current score of each player.
score :: GameExec m (ByPlayer Float)
score = liftM (ByPlayer . map sum . transpose . asList2) payoff

-------------------------
-- Selection Functions --
-------------------------

-- Apply selection to each element of a list.
each :: (GameExec m a -> GameExec m b) -> GameExec m [a] -> GameExec m [b]
each f xs = (sequence . map f . map return) =<< xs

-- ByPlayer Selection --

-- The index of the current player.
myIndex :: GameExec m Int
myIndex = do Decision p _ <- liftM _location get
             return (p-1)

my :: GameExec m (ByPlayer a) -> GameExec m a
my x = liftM2 (!!) (liftM asList x) myIndex

-- Selects the next player's x.
his :: GameExec m (ByPlayer a) -> GameExec m a
his x = do ByPlayer as <- x
           i <- myIndex
           g <- game
           return $ as !! ((i+1) `mod` numPlayers g)

her :: GameExec m (ByPlayer a) -> GameExec m a
her = his

our :: GameExec m (ByPlayer a) -> GameExec m [a]
our = liftM asList

their :: GameExec m (ByPlayer a) -> GameExec m [a]
their x = do ByPlayer as <- x
             i <- myIndex
             return $ (take i as) ++ (drop (i+1) as)

playern :: Int -> GameExec m (ByPlayer a) -> GameExec m a
playern i x = do ByPlayer as <- x
                 return $ as !! (i-1)

-- ByGame Selection --

every :: GameExec m (ByGame a) -> GameExec m [a]
every = liftM asList

first :: GameExec m (ByGame a) -> GameExec m a
first = liftM (last . asList)

firstn :: Int -> GameExec m (ByGame a) -> GameExec m [a]
firstn n = liftM (reverse . take n . reverse . asList)

prev :: GameExec m (ByGame a) -> GameExec m a
prev = liftM (head . asList)

prevn :: Int -> GameExec m (ByGame a) -> GameExec m [a]
prevn n = liftM (take n . asList)

gamen :: Int -> GameExec m (ByGame a) -> GameExec m a
gamen i x = do ByGame as <- x
               n <- numGames
               return $ as !! (n-i)

---------------
-- Utilities --
---------------

maxIndex :: (Ord a) => [a] -> Int
maxIndex as = fromJust $ elemIndex (maximum as) as
