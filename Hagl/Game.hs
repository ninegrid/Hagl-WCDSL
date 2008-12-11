{-# OPTIONS_GHC -fglasgow-exts -XUndecidableInstances #-}

module Hagl.Game where

import Data.List
import qualified Data.Tree as Tree

import Hagl.Lists

---------------------
-- Game Definition --
---------------------

class Game g where
  type Move g
  type State g
  numPlayers :: g -> Int
  gameTree   :: g -> GameTree g
  info       :: g -> Info g

------------------------
-- Information Groups --
------------------------

type Info g = GameTree g -> InfoGroup g

data InfoGroup g = Perfect (GameTree g)
                 | Imperfect [GameTree g]
                 | NoInfo

--
-- Smart constructors for deriving information groups for classes of games.
--

perfect :: g -> Info g
perfect _ = Perfect

simultaneous :: g -> Info g
simultaneous _ _ = NoInfo

----------------
-- Game Trees --
----------------

type PlayerIx = Int
type Payoff = ByPlayer Float

type Edge g = (Move g, GameTree g)

data GameTree g = Node (State g) (NodeType g)
data NodeType g = DN PlayerIx [Edge g] -- decision made by a player
                | CN (Dist (Edge g))   -- random move from distribution
                | PN Payoff            -- terminating payoff

--
-- Smart constructors for defining stateless game trees.
--

decision :: State g ~ () => PlayerIx -> [Edge g] -> GameTree g
decision p = Node () . DN p

chance :: State g ~ () => Dist (Edge g) -> GameTree g
chance = Node () . CN

payoff :: State g ~ () => Payoff -> GameTree g
payoff = Node () . PN

--
-- Functions for traversing game trees.
--

-- The moves available from a node.
availMoves :: GameTree g -> [Move g]
availMoves (Node _ (DN _ es)) = [m | (m,_) <- es]
availMoves (Node _ (CN d)) = [m | (_,(m,_)) <- d]
availMoves _ = []

-- The immediate children of a node.
children :: GameTree g -> [GameTree g]
children (Node _ (DN _ es)) = [n | (_,n) <- es]
children (Node _ (CN d)) = [n | (_,(_,n)) <- d]
children _ = []

-- Nodes in BFS order.
bfs :: GameTree g -> [GameTree g]
bfs t = let b [] = []
            b ns = ns ++ b (concatMap children ns)
        in b [t]

-- Nodes DFS order.
dfs :: GameTree g -> [GameTree g]
dfs t = t : concatMap dfs (children t)

---------------
-- Instances --
---------------

-- Eq

instance (Eq (Move g), Eq (State g)) => Eq (InfoGroup g) where
  (Perfect t1) == (Perfect t2) = t1 == t2
  (Imperfect t1) == (Imperfect t2) = t1 == t2
  NoInfo == NoInfo = True
  _ == _ = False

instance (Eq (Move g), Eq (State g)) => Eq (GameTree g) where
  (Node s1 t1) == (Node s2 t2) = s1 == s2 && t1 == t2

instance (Eq (Move g), Eq (State g)) => Eq (NodeType g) where
  (DN p1 es1) == (DN p2 es2) = p1 == p2 && es1 == es2
  (CN d1) == (CN d2) = d1 == d2
  (PN v1) == (PN v2) = v1 == v2
  _ == _ = False

-- Show

instance Show (Move g) => Show (InfoGroup g) where
  show (Perfect t) = show t
  show (Imperfect ts) = unlines $ intersperse "*** OR ***" (map show ts)
  show NoInfo = "Cannot show this location in the game tree."

instance Show (Move g) => Show (GameTree g) where
  show g = condense $ Tree.drawTree $ t "" g
    where t pre (Node _ nt) =
            let s (DN p es) = pre ++ "Player " ++ show p
                s (CN d) = pre ++ "Chance"
                s (PN (ByPlayer vs)) = pre ++ show vs
                c (DN p es) = [t (show m ++ " -> ") g | (m,g) <- es]
                c (CN d) = [t (show i ++ " * " ++ show m ++ " -> ") g | (i,(m,g)) <- d]
                c (PN _) = []
            in Tree.Node (s nt) (c nt)
          condense s = let empty = not . and . map (\c -> c == ' ' || c == '|')
                       in unlines $ filter empty $ lines s
{-
-- Game tree as a Data.Tree structure.
asTree :: Game g mv => g -> Tree g
asTree g = Node g $ map asTree (children g)

-- The highest number player from this *finite* game tree.
maxPlayer :: Game g mv => g -> PlayerIx
maxPlayer g = foldl1 max $ map player (dfs g)
  where player g = case nextAction g of
            (Decision p _) -> p
            _ -> 0
-}

-- Game Definition
{-
data Game mv = Game {
    numPlayers :: Int,
    info       :: GameTree mv -> InfoGroup mv,
    tree       :: GameTree mv
}

-- Game Tree
data GameTree mv = Decision PlayerIx [(mv, GameTree mv)]
                 | Chance [(Int, GameTree mv)]
                 | Payoff [Float]
                 deriving Eq

data InfoGroup mv = Perfect (GameTree mv)
                  | Imperfect [GameTree mv]
                  deriving Eq


-- Instance Declarations
instance (Show mv) => Show (GameTree mv) where
  show t = condense $ drawTree $ s "" t
    where s p (Decision i ts) = Node (p ++ "Player " ++ show i) [s (show m ++ " -> ") t | (m, t) <- ts]
          s p (Chance ts) = Node (p ++ "Chance") [s (show c ++ " -> ") t | (c, t) <- ts]
          s p (Payoff vs) = Node (p ++ show vs) []
          condense s = let empty = not . and . map (\c -> c == ' ' || c == '|')
                       in unlines $ filter empty $ lines s
instance (Show mv) => Show (Game mv) where
  show g = show (tree g)
instance (Show mv) => Show (InfoGroup mv) where
  show (Perfect t) = show t
  show (Imperfect ts) = unlines $ intersperse " ** or **" (map (init . show) ts)

----------------------------
-- Normal Form Definition --
----------------------------

-- Construct a game from a Normal-Form definition
normal :: Int -> [[mv]] -> [[Float]] -> Game mv
normal np mss vs = Game np group (head (level 1))
  where level n | n > np = [Payoff v | v <- vs]
                | otherwise = let ms = mss !! (n-1) 
                                  bs = chunk (length ms) (level (n+1)) 
                              in map (Decision n . zip ms) bs
        group (Decision n _) = Imperfect (level n)
        group t = Perfect t

-- Construct a two-player Normal-Form game, where each player has the same moves.
matrix :: [mv] -> [[Float]] -> Game mv
matrix ms = normal 2 [ms,ms]

-- Construct a two-player Zero-Sum game, where each player has the same moves.
zerosum :: [mv] -> [Float] -> Game mv
zerosum ms vs = matrix ms [[v, -v] | v <- vs]

-------------------------------
-- Extensive Form Definition --
-------------------------------

-- Build a game from a tree. Assumes a finite game tree.
extensive :: GameTree mv -> Game mv
extensive t = Game (maxPlayer t) Perfect t

-----------------------------
-- State-Driven Definition --
-----------------------------

{- Build a state-based game.
 - Args:
     * Number of players.
     * Whose turn is it?
     * Is the game over?
     * What are the available moves?
     * Execute a move and return the new state.
     * What is the payoff for this (final) state?
     * Initial state. -}
stateGame :: Int -> (s -> PlayerIx) -> (s -> PlayerIx -> Bool) -> 
             (s -> PlayerIx -> [mv]) -> (s -> PlayerIx -> mv -> s) -> 
             (s -> PlayerIx -> [Float]) -> s -> Game mv
stateGame np who end moves exec pay init = Game np Perfect (tree init)
  where tree s | end s p = Payoff (pay s p)
               | otherwise = Decision p [(m, tree (exec s p m)) | m <- moves s p]
          where p = who s

{- Build a state-based game where the players take turns. Player 1 goes first.
 - Args:
     * Number of players.
     * Is the game over?
     * What are the available moves?
     * Execute a move and return the new state.
     * What is the payoff for this (final) state?
     * Initial state. -}
takeTurns :: Int -> (s -> PlayerIx -> Bool) -> (s -> PlayerIx -> [mv]) ->
             (s -> PlayerIx -> mv -> s) -> (s -> PlayerIx -> [Float]) -> s ->
             Game mv
takeTurns np end moves exec pay init =
    stateGame np snd (lft end) (lft moves) exec' (lft pay) (init, 1)
  where exec' (s,_) p m = (exec s p m, (mod p np) + 1)
        lft f (s,_) p = f s p

----------------------------
-- Game Tree Construction --
----------------------------

-- Construct a payoff where player w wins (1) and all other players,
-- out of np, lose (-1).
winner :: Int -> PlayerIx -> [Float]
winner np w = replicate (w-1) (-1) ++ (fromIntegral np - 1) : replicate (np - w) (-1)

-- Construct a payoff where player w loses (-1) and all other players,
-- out of np, win (1).
loser :: Int -> PlayerIx -> [Float]
loser np l = replicate (l-1) 1 ++ (1 - fromIntegral np) : replicate (np - l) 1

tie :: Int -> [Float]
tie np = replicate np 0

-- Construct a decision node with only one option.
player :: PlayerIx -> (mv, GameTree mv) -> GameTree mv
player i m = Decision i [m]

-- Combines two game trees.
(<+>) :: GameTree mv -> GameTree mv -> GameTree mv
Payoff as <+> Payoff bs = Payoff (zipWith (+) as bs)
Chance as <+> Chance bs = Chance (as ++ bs)
Decision a as <+> Decision b bs | a == b = Decision a (as ++ bs)

-- Add a decision branch to a game tree.
(<|>) :: GameTree mv -> (mv, GameTree mv) -> GameTree mv
Decision i ms <|> m = Decision i (m:ms)

-------------------------
-- Game Tree Traversal --
-------------------------


-- Return the moves that are available from this node.
availMoves :: GameTree mv -> [mv]
availMoves (Decision _ ms) = map fst ms
availMoves _ = []

-- The immediate children of a node.
children :: GameTree mv -> [GameTree mv]
children (Decision _ ms) = map snd ms
children (Chance cs) = map snd cs
children _ = []

-}