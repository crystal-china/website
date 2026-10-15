class NodeQuery < Node::BaseQuery
  def sorted : self
    order_by(:position, :desc).order_by(:name, :asc)
  end
end
