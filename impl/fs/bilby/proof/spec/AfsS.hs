{-# LANGUAGE MultiWayIf #-}

module AfsS where

import FunBucket
import VfsT

import Data.Bits
import qualified Data.Map as M

type Byte = U8
type Page = [U8]
type Dir = M.Map [U8] Ino
type File_data = [Page]

data Afs_inode_type = IDir Dir
                    | IReg File_data
                    | ILnk [U8]

-- TODO: a few afs_inode_is_ definitions

data Afs_inode = Afs_inode {
  i_type  :: Afs_inode_type
, i_ino   :: Ino
, i_nlink :: U32
, i_size  :: U64
, i_mtime :: TimeT
, i_ctime :: TimeT
, i_uid   :: U32
, i_gid   :: U32
, i_mode  :: Mode
, i_flags :: U32
}


type Readdir_ctx = (U32, Dir)

type Afs_map = M.Map Ino Afs_inode

data Afs_state = Afs_state {
  a_is_readonly :: Bool
, a_current_time :: TimeT
, a_medium_afs :: Afs_map
, a_medium_updates :: [Afs_map -> Afs_map]
}

a_afs_update_n :: Int -> Afs_map -> [Afs_map -> Afs_map] -> Afs_map
a_afs_update_n n afs_st updates = foldr id afs_st (take n updates)

a_afs_updated :: Afs_map -> [Afs_map -> Afs_map] -> Afs_map
a_afs_updated afs_st updates = a_afs_update_n (length updates) afs_st updates

updated_afs :: Afs_state -> Afs_map
updated_afs adata = a_afs_updated (a_medium_afs adata) (a_medium_updates adata)

i_type_dir :: Afs_inode_type -> Dir
i_type_dir it = case it of IDir dir -> dir

i_dir :: Afs_inode -> Dir
i_dir = i_type_dir . i_type

i_dir_update :: (Dir -> Dir) -> Afs_inode -> Afs_inode
i_dir_update m i = i { i_type = IDir (m $ i_dir i) }

i_type_data :: Afs_inode_type -> File_data
i_type_data it = case it of IReg dat -> dat  -- change from `data` to `dat` to avoid keyword

i_data :: Afs_inode -> File_data
i_data = i_type_data . i_type

i_data_update :: (File_data -> File_data) -> Afs_inode -> Afs_inode
i_data_update m i = i { i_type = IReg (m $ i_data i) }

i_type_path :: Afs_inode_type -> [Byte]
i_type_path it = case it of ILnk path -> path

i_path :: Afs_inode -> [Byte]
i_path = i_type_path . i_type

i_path_update :: ([Byte] -> [Byte]) -> Afs_inode -> Afs_inode
i_path_update m i = i { i_type = ILnk (m $ i_path i) }


i_size_from_afs_inode_type :: Afs_inode_type -> U64
i_size_from_afs_inode_type (IDir dir) = undefined
i_size_from_afs_inode_type (IReg dat) = count (concat dat)
i_size_from_afs_inode_type (ILnk path) = count path

i_size_from_type :: Afs_inode -> U64
i_size_from_type = i_size_from_afs_inode_type . i_type

afs_inode_to_vnode :: Afs_inode -> VfsInode
afs_inode_to_vnode i = VfsInode {
    v_ino = i_ino i
  , v_nlink = i_nlink i
  , v_size = i_size i
  , v_mtime = i_mtime i
  , v_ctime = i_ctime i
  , v_uid = i_uid i
  , v_gid = i_gid i
  , v_mode = i_mode i
  , v_flags = i_flags i
  }

afs_inode_from_vnode :: Vnode -> Afs_inode
afs_inode_from_vnode v = Afs_inode {
    i_type = if | v_mode v .&. s_IFREG /= 0 -> IReg [] 
                | v_mode v .&. s_IFDIR /= 0 -> IDir M.empty
                | otherwise -> ILnk []
  , i_ino = v_ino v
  , i_nlink = v_nlink v
  , i_size = v_size v
  , i_mtime = v_mtime v
  , i_ctime = v_ctime v
  , i_uid = v_uid v
  , i_gid = v_gid v
  , i_mode = v_mode v
  , i_flags = v_flags v
  }

error_if_readonly :: Afs_state -> Cogent_monad (R11 (ErrCode, Afs_state) Afs_state)
error_if_readonly as = return $ if a_is_readonly as
                                  then Error (eRoFs, as)
                                  else Success as