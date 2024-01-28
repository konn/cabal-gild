{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# OPTIONS_GHC -Wno-deprecations #-}

-- |
-- License: GPL-3.0-or-later
-- Copyright: Oleg Grenrus
module CabalGild.Refactoring.ExpandExposedModules
  ( refactoringExpandExposedModules,
  )
where

import CabalGild.Monad
import CabalGild.Pragma
import CabalGild.Prelude
import CabalGild.Refactoring.Type
import qualified Distribution.Fields as C
import qualified Distribution.ModuleName as C

refactoringExpandExposedModules :: FieldRefactoring
refactoringExpandExposedModules C.Section {} = pure Nothing
refactoringExpandExposedModules (C.Field name@(C.Name (_, _, pragmas) _n) fls) = do
  dirs <- parse pragmas
  files <- traverseOf (traverse . _1) getFiles dirs

  let newModules :: [C.FieldLine CommentsPragmas]
      newModules =
        catMaybes
          [ return $ C.FieldLine emptyCommentsPragmas $ toUTF8BS $ intercalate "." parts
            | (files', mns) <- files,
              file <- files',
              let parts = splitDirectories $ dropExtension file,
              all C.validModuleComponent parts,
              let mn = C.fromComponents parts, -- TODO: don't use fromComponents
              mn `notElem` mns
          ]

  pure $ case newModules of
    [] -> Nothing
    _ -> Just (C.Field name (newModules ++ fls))
  where
    parse :: (MonadCabalGild r m) => [FieldPragma] -> m [(FilePath, [C.ModuleName])]
    parse = fmap mconcat . traverse go
      where
        go :: (MonadCabalGild r m) => FieldPragma -> m [(FilePath, [C.ModuleName])]
        go (PragmaExpandModules fp mns) = return [(fp, mns)]
        go p = do
          displayWarning $ "Skipped pragma " ++ show p
          return []
