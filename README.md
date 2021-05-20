# Nested Resource Routing

## Learning Goals

- Understand the value of nested routes
- Create nested routes
- Understand how nested resource params are named

## Introduction

We're going to keep working on our AirBudNB application, augmenting it to filter
reviews by listing in a user-friendly and RESTful way.

To set up the app, run:

```sh
bundle install
rails db:migrate db:seed
rails s
```

### URL As Data

You've encountered REST already, but, just to review, it stands for
REpresentational State Transfer and encapsulates a way of structuring a URL so
that access to specific resources is predictable and standardized.

In practice, that means that, if we type `rails s` and run our app,
browsing to `/reviews` will show us the index of all `Review` objects. And if we
want to view a specific `DogHouse`, we can guess the URL for that (as long as we
know the dog house's `id`) by going to `/dog_house/:id`.

Why do we care?

Let's imagine we added a filter feature to our reviews page:

![reviews filter](https://raw.githubusercontent.com/learn-co-curriculum/phase-4-nested-resource-routing/master/reviews-filter.png)

When the filter is active, we can make a request to our backend to retrieve
only the reviews that match the selected dog house:

`http://localhost:3000/reviews?doghouse=1`

That's the opposite of REST. That makes me _stressed_. While using query params
like in the link above could work, we can do better by following REST
conventions.

### Dynamic Route Segments

What we'd love to end up with here is something like `/dog_house/1/reviews` for
all of a dog house's reviews and `/dog_house/1/reviews/5` to see an individual
review for that dog house.

We know we can build out a route with dynamic segments, so our first instinct
might be to just define these in `routes.rb` like this:

```ruby
# config/routes.rb
  ...
  get '/dog_house/:dog_house_id/reviews'
  get '/dog_house/:dog_house_id/reviews/:review_id'
```

After adding those routes, let's check it out by browsing to
`/dog_house/1/reviews`.

Oops. Error. Gotta tell those routes explicitly which controller actions will
handle them. Okay, let's make it look more like this:

```ruby
# config/routes.rb
  ...
  get '/dog_houses/:dog_house_id/reviews', to: 'dog_houses#reviews_index'
  get '/dog_houses/:dog_house_id/reviews/:id', to: 'dog_houses#review'
```

And to handle our new filtering routes, we'll need to add some code in our
`dog_houses_controller` to actually do the work.

```ruby
  # app/controllers/dog_houses_controller.rb
  ...

  def reviews_index
    dog_house = DogHouse.find(params[:dog_house_id])
    reviews = dog_house.reviews
    render json: reviews, include: :dog_house
  end

  def review
    review = Review.find(params[:id])
    render json: review, include: :dog_house
  end
```

**Note:** If your IDs are different and you are having trouble with the URLs,
try running `rails db:reset` to reset your database.

We did it! We have much nicer URLs now. Are we done? Of course not.

If we look at our `routes.rb`, we can already see it getting messy. Instead of
something nice like `resources :dog_houses`, now we're specifying controller
actions and HTTP verbs just to do a simple filter of a dog house's reviews.

Beyond that, our DRY (Don't Repeat Yourself) and Separation of Concerns klaxons
should be wailing because the code to find all reviews and to find individual
reviews by their ID is essentially repeated in both the `reviews_controller` and
the `dog_houses_controller`. These aren't really the concern of the
`dog_houses_controller`, and we can tell that because we're directly rendering
`Review`-related data.

Seems like Rails would have a way to bail us out of this mess.

### Nested Resource Routes

Turns out, Rails _does_ give us a way to make this a lot nicer.

If we look again at our models, we see that a dog house `has_many :reviews` and
a review `belongs_to :dog_house`. Since a review can logically be considered a
_child_ object of a dog house, it can also be considered a _nested resource_ of
a dog house for routing purposes.

Nested resources give us a way to document that parent/child relationship in our
routes and, ultimately, our URLs.

Let's get back into `routes.rb`, delete the two routes we just added, and
recreate them as nested resources. We should end up with something like this:

```ruby
# config/routes.rb

Rails.application.routes.draw do

  resources :dog_houses, only: [:show] do
    # nested resource for reviews
    resources :reviews, only: [:show, :index]
  end

  resources :reviews, only: [:show, :index, :create]
end
```

Now we have the resourced `:dog_houses` route, but by adding the `do...end` we
can pass it a block of its nested routes.

We can still do things to the nested resources that we do to a non-nested
resource, like limit them to only certain actions. In this case, we only want to
nest `:show` and `:index` under `:dog_houses`.

Below that, we still have our regular resourced `:reviews` routes because we
still want to let people see all reviews or a single review, create reviews,
etc., outside of the context of a dog house.

You can see the routes available by running `rails routes`:

```txt
Prefix            Verb  URI Pattern                                     Controller#Action
dog_house_reviews GET   /dog_houses/:dog_house_id/reviews(.:format)     reviews#index
 dog_house_review GET   /dog_houses/:dog_house_id/reviews/:id(.:format) reviews#show
        dog_house GET   /dog_houses/:id(.:format)                       dog_houses#show
          reviews GET   /reviews(.:format)                              reviews#index
                  POST  /reviews(.:format)                              reviews#create
```

Now we need to update our `reviews_controller` to handle the nested resource we
just set up. Notice how now we are dealing with the `reviews_controller` rather
than the `dog_houses_controller`. Ultimately, the resource we're requesting is
related to reviews, so Separation of Concerns tells us to put that code in the
`reviews_controller`. And, since we already have actions to handle `:show` and
`:index`, we won't be repeating ourselves like we did in the
`dog_houses_controller`.

Let's update `index` to account for the new routes:

```ruby
# app/controllers/reviews_controller.rb

  def index
    if params[:dog_house_id]
      dog_house = DogHouse.find(params[:dog_house_id])
      reviews = dog_house.reviews
    else
      reviews = Review.all
    end
    render json: reviews, include: :dog_house
  end
```

We added a condition to the `reviews#index` action to account for whether the
user is trying to access the index of _all_ reviews (`Review.all`) or just the
index of all reviews _for a certain dog house_ (`dog_house.reviews`).

The condition hinges on whether there's a `:dog_house_id` key in the `params`
hash — in other words, whether the user navigated to
`/dog_houses/:dog_house_id/reviews` or simply `/reviews`. We didn't have to
create any new methods or make explicit calls to render new data. We just added
a simple check for `params[:dog_house_id]`, and we're good to go.

Where is `params[:dog_house_id]` coming from? Rails provides it for us through
the nested route, so we don't have to worry about a collision with the `:id`
parameter that `reviews#show` is looking for. Rails takes the parent resource's
name and appends `_id` to it for a nice, predictable way to find the parent
resource's ID. Since some of our review routes are nested like this:

```rb
resources :dog_houses, only: [:show] do
  resources :reviews, only: [:show, :index]
end
```

We end up with these routes for reviews (notice the dynamic portions of the URI
Patterns):

```txt
Verb  URI Pattern                                     Controller#Action
GET   /dog_houses/:dog_house_id/reviews               reviews#index
GET   /dog_houses/:dog_house_id/reviews/:id           reviews#show
```

You'll also notice we didn't make a single change to the `reviews#show` action.
What about the new `/dog_house_id/:dog_house_id/reviews/:id` route that we
added?

Remember, the point of nesting our resources is to DRY up our code. We had to
create a conditional for the `reviews#index` action because it renders
_different_ sets of reviews depending on the path,
`/dog_house_id/:dog_house_id/reviews` or `/reviews`. Conversely, the
`reviews#show` route is going to render the _same_ information — data concerning
a single review — regardless of whether it is accessed via
`/dog_house_id/:dog_house_id/reviews` or `/reviews/:id`.

For good measure, let's go into our `dog_houses_controller.rb` and delete the
two actions (`review` and `reviews_index`) that we added above so that it looks like
this:

```ruby
# app/controllers/dog_houses_controller.rb

class DogHousesController < ApplicationController

  def show
    dog_house = DogHouse.find_by(id: params[:id])
    if dog_house
      render json: dog_house, include: :reviews
    else
      render json: { error: "Dog house not found" }, status: :not_found
    end
  end

end
```

**Top-tip:** Keep your application clean and easy to maintain by always removing
unused code.

### Caveat on Nesting Resources More Than One Level Deep

You can nest resources more than one level deep, but that is generally a bad idea.

Imagine if we also had comments on a review. This would be a perfectly fine use of nesting:

```ruby
resources :reviews do
  resources :comments
end
```

We could then access a reviews's comments with `/reviews/1/comments`. That makes
a lot of sense.

But if we then tried to add to our already nested `reviews` resource...

```ruby
resources :dog_houses do
  resources :reviews do
    resources :comments
  end
end
```

Now we're getting into messy territory. Our URL is
`/dog_houses/1/reviews/1/comments`, and we have to handle that filtering in our
controller.

But if we lean on our old friend Separation of Concerns, we can conclude that a
reviews's comments are not the concern of a dog house and therefore don't
belong nested two levels deep under the `:dog_houses` resource.

In addition, the reason to put the ID of the resource in the URL is so that we
have access to it in the controller. If we know we have the review with an ID of
`1`, we can use our Active Record relationships to call:

```ruby
  review = Review.find(params[:id])
  review.dog_house
  # This will tell us which dog house the review was for!
  # We don't need this information in the URL
```

## Conclusion

Nesting resources is a powerful tool that helps you keep your routes neat and
tidy and is better than dynamic route segments for representing parent/child
relationships in your system.

However, as a general rule, you should only nest resources one level deep and
ensure that you are considering Separation of Concerns in your routing.

## Resources

- [Routing: Nested Resources](https://guides.rubyonrails.org/routing.html#nested-resources)
