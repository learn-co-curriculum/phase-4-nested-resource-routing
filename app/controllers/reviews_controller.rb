class ReviewsController < ApplicationController

  def index
    reviews = Review.all
    render json: reviews, include: :dog_house
  end

end
