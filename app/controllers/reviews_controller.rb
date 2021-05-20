class ReviewsController < ApplicationController

  def index
    reviews = Review.all
    render json: reviews, include: :dog_house
  end

  def show
    review = Review.find_by(id: params[:id])
    if review
      render json: review
    else
      render json: { error: "Review not found" }, status: :not_found
    end
  end

  def create
    review = Review.create(review_params)
    render json: review, status: :created
  end

  private

  def review_params
    params.permit(:username, :comment, :rating)
  end

end
