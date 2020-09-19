local VERBOSE = false
local function log(...)
  if VERBOSE then print('[INFO]',...) end
end

--[[
This is an implementation of a set that maintains an <= ordering between its items
by way of a self-balancing binary search (AVL) tree.

It's important to keep in mind the invariants of an AVL tree when reasoning
about the behavior:
  - Each node has at most two subtrees
  - Each node is valued greater than all nodes in its "left" subtree, and lesser
    than all nodes in its "right" subtree
  - Trees are traversed from "left" to "right" and thus in ascending order of value
  - Each node is ranked according to its height in the tree
  - Subtrees never rank higher than the root
  - Subtrees with the same immediate root never differ in rank by more than 1
]]

local tree = {}

--[[
  The height of a node is the length of the longest path downward from that node
  to a leaf. Thus, the height of the root node is the height of the tree, and the
  height of a leaf is zero.

  Conventionally, an empty tree has a height of -1.
]]
local BASE_HEIGHT = -1
local function _leaf(item)
  log('(_leaf)', item)
  return setmetatable(
    {
      value = item,
      __height = BASE_HEIGHT + 1,
      __left = nil,
      __right = nil,
    },
    { __index = tree })
end

local function _get_height_safely(node)
  return node and node.__height or BASE_HEIGHT
end

-- The proper height of a node is 1 greater than the height of its largest subtree.
local function _compute_proper_height(node)
  return 1 +
    math.max(
      _get_height_safely(node.__left),
      _get_height_safely(node.__right)
    )
end

-- The balance factor will be in {-1, 0, 1} when the tree is balanced.
-- Otherwise, it will be negative when the left side is too tall, and positive
-- when the right side is too tall.
local function _balance_factor(node)
  local left_height = _get_height_safely(node.__left)
  local right_height = _get_height_safely(node.__right)

  return (right_height - left_height)
end

--[[ NOTE(dabrady)
  Balancing a binary tree changes the structure without interfering with the
  ordering of its nodes.

  We use this behavior in particular to ensure our tree is compact in terms of
  height. Without this property, our set would technically still be ordered, but
  manipulating it would grow less performant in direct proportion to its size.
]]
local function _balance(root_node)
  log('(_balance)', root_node)
  if not root_node then
    print('\t(early return: nil)')
    return nil
  end

  --[[
    A single tree rotation is a constant-time operation that essentially
    brings one node 'up' and pushes one node 'down'.

    Excellent resources on tree rotation algorithms:
    @see https://en.wikipedia.org/wiki/Tree_rotation
    @see https://www.cs.swarthmore.edu/~brody/cs35/f14/Labs/extras/08/avl_pseudo.pdf
  ]]
  local function __rotate(root_node, rotation_side, opposite_side)
    log('\t(__rotate)', rotation_side)
    --[[
      Rotation is an operation that takes a node and its two subnodes, and
      changes their relationship such that the original node becomes a subnode of
      one of the others, and the other becomes a 'supernode' to the original.

      (One of the sub-subtrees becomes orphaned in this process, and is reassigned
      to maintain the tree invariants.)

      The subnode in the direction of the rotation is the node that is 'lowered',
      and thus its opposite is the node that gets 'promoted'.

               (d)
              /   \
            (b)  (e)                   (b)
           /   \         right        /   \
         (a)  (c)       rotate      (a)  (d)
                        ----->          /   \
                                      (c)  (e)
    ]]
    local pivot_node = root_node[opposite_side]
    root_node[opposite_side] = pivot_node[rotation_side]
    pivot_node[rotation_side] = root_node

    root_node.__height = _compute_proper_height(root_node)
    pivot_node.__height = _compute_proper_height(pivot_node)

    return pivot_node
  end

  local function __rotate_left(node)
    return __rotate(node, "__left", "__right")
  end

  local function __rotate_right(node)
    return __rotate(node, "__right", "__left")
  end

  root_node.__height = _compute_proper_height(root_node)

  -- NOTE(dabrady) If the balance factor of the root is in violation, the tree is
  -- unbalanced and needs restructuring.
  local balance_factor = _balance_factor(root_node)
  if balance_factor < -1 then
    -- The left side is too tall, so lower it.
    log('\tleft side too tall')

    -- When the "inside edge" of a subtree is longer than the "outside edge", we
    -- actually need to make a double-rotation to properly rebalance.
    local left_balance = _balance_factor(root_node.__left)
    if left_balance > 0 then
      log('\tinside edge too tall')
      root_node.__left = __rotate_left(root_node.__left)
    end

    return __rotate_right(root_node)
  elseif balance_factor > 1 then
    log('\tright side too tall')
    -- The right side is too tall, so lower it.

    local right_balance = _balance_factor(root_node.__right)
    if right_balance < 0 then
      log('\tinside edge too tall')
      root_node.__right = __rotate_right(root_node.__right)
    end

    return __rotate_left(root_node)
  end

  -- We've determined the tree is balanced, so give it back.
  log('(_balance) balanced root:', root_node)
  return root_node
end

function tree:add(item)
  log('(tree.add)', item)

  if not self or not self.value then
    -- Our base case: we've reached the end of a branch, and must grow a new leaf.
    log('\tgrowing new leaf for '..item)
    return _leaf(item)
  end

  if item < self.value then
    log('\tgoing left from '..self.value)
    -- Go left.
    self.__left = tree.add(self.__left, item)
  elseif item > self.value then
    log('\tgoing right from '..self.value)
    -- Go right.
    self.__right = tree.add(self.__right, item)
  else
    -- Do nothing, item already represented by the this node.
  end

  -- Rebalance and return this node.
  return _balance(self)
end

function tree:remove(item)
  if not self then
    return nil
  end

  -- Found it, time to do some switchery.
  if item == self.value then
    --[[
      If it only has one subtree, just straight up replace it with that subtree;
      no need to do anything fancy in this case. E.g.

          (b)                         (b)
         /   \      remove (d)       /   \
       (a)  (d)     --------->     (a)  (c)
           /
         (c)
    ]]
    if not ( self.__left and self.__right ) then
      return self.__left or self.__right
    end

    --[[
      If this node is load-bearing (i.e. has both subtrees), we need to do some
      more complex transplanting to maintain our order invariant.

      What should happen here?

          (b)
         /   \      remove (b)     ????
       (a)  (d)     --------->
           /   \
         (c)  (e)

      One approach, which I will use here, is to simply replace the node-to-remove
      with the "next" node in the tree (relative to the order invariant).

          (b)                         (c)
         /   \      remove (b)       /   \
       (a)  (d)     --------->     (a)  (d)
           /   \                          \
         (c)  (e)                        (e)

      Such an action is a bit tricky when the "next" node has a subtree (it will
      have either zero or one, by definition of "next") because we have to decide
      where to put that subtree. But this is solved by considering a "node
      replacement" to be a copy-remove-rebalance action, in which case we have a
      simple case of recursion.

          (c)                         (d)
         /   \      remove (c)       /   \
       (b)  (f)     --------->     (b)  (f)
      /    /   \                  /    /   \
    (a)  (d)  (g)               (a)  (e)  (g)
            \
           (e)
    ]]

    -- The "next" node is always the bottom-left node of the right side of the tree.
    local next_node = self.__right
    while next_node do
      next_node = next_node.__left
    end

    -- Change the world.
    local new_self = tree.remove(self, next_node.value)
    -- Forget the old one.
    new_self.value = next_node.value
    return new_self
  end

  -- Walk the tree until we find the item, then remove it or die trying.
  if item < self.value then
    self.__left = tree.remove(self.__left, item)
  elseif item > self.value then
    self.__right = tree.remove(self.__right, item)
  end

  -- Rebalance and return this node.
  return _balance(self)
end

-----

local orderedset = {}
local function _make_set()
  log('(_make_set)')
  return setmetatable(
    {},
    {
      root = nil,
      size = 0, -- the number of items in our ordered set
      __len = function(t) return getmetatable(t).size end,
    }
  )
end

function orderedset.from(list)
  log('(orderedset.from)', list)
  local set = _make_set()

  if list then
    assert(type(list) == "table")
    for _,item in ipairs(list) do
      log('\tadding', item)
      orderedset.add(set, item)
    end
  end

  return set
end

function orderedset.add(set, item)
  log('(orderedset.add)', item)
  if not set then
    error('need a set to add to')
  end

  if not item then
    -- Don't allow nodes without value.
    return nil
  end

  local meta = getmetatable(set)
  if not meta.root then
    -- The tree is empty, so return a new root.
    log('\t(empty tree)')
    meta.root = _leaf(item)
  else
    log('\t(non-empty tree)')
    meta.root = meta.root:add(item)
  end

  -- Keep a table indexed by the items for performant lookups
  if not set[item] then
    set[item] = true
    meta.size = meta.size + 1
  end

  return item
end

function orderedset.remove(set, item)
  log('(orderedset.remove)', item)
  if not set then
    error('need a set to remove from')
  end

  if not item then
    return nil
  end

  local meta = getmetatable(set)
  meta.root = meta.root and meta.root:remove(item)

  -- Keep a table indexed by the items for performant lookups
  if set[item] then
    set[item] = nil
    meta.size = meta.size - 1
  end

  return nil
end

function orderedset.iterate(set)
  log('(orderedset.iterate)')
  if not set then
    error('need a set to iterate over')
  end

  local function __traverse(node)
    if not node then
      return nil
    end

    __traverse(node.__left)
    coroutine.yield(node.value)
    __traverse(node.__right)
  end

  return coroutine.wrap(function()
    __traverse(getmetatable(set).root)
  end)
end

return setmetatable(
  orderedset,
  {
    __call = function(_, ...) return orderedset.from(...) end
  }
)
