# R script for movie recommendations

# Install and load necessary libraries
if (!require("dplyr")) install.packages("dplyr")
if (!require("data.table")) install.packages("data.table")
if (!require("reshape2")) install.packages("reshape2")
library(dplyr)
library(data.table)
library(reshape2)

# Load data
movies <- fread("movie.csv", col.names = c("movieId", "title", "genres"))
ratings <- fread("rating.csv", col.names = c("userId", "movieId", "rating", "timestamp"))

# Randomly select 1000 unique users
set.seed(123)  # Ensure reproducibility
selected_users <- sample(unique(ratings$userId), 1000)

# Filter ratings to include only selected users
filtered_ratings <- ratings %>%
  filter(userId %in% selected_users) %>%
  select(-timestamp)  # Drop the 'timestamp' column

# Merge movies and ratings
movie_ratings <- merge(movies, filtered_ratings, by = "movieId")

# Create a user-item rating matrix
user_rating_matrix <- dcast(
  movie_ratings, 
  userId ~ title, 
  value.var = "rating", 
  fun.aggregate = sum
)

# Similarity computation function
compute_similarity <- function(userInput, user_rating) {
  # Validate if the userInput movies exist in the dataset
  valid_movies <- userInput[userInput %in% colnames(user_rating)]
  
  if (length(valid_movies) == 0) 
    stop("None of the specified movies are present in the dataset.")
  
  # Compute Pearson similarity scores
  similarity <- rowSums(sapply(valid_movies, function(movie) {
    sapply(user_rating, function(column) {
      cor(column, user_rating[[movie]], method = "pearson", use = "pairwise.complete.obs")
    })
  }))
  
  return(similarity)
}

# Recommendation generation function
generate_recommendations <- function(userInput) {
  # Compute similarity
  similarity <- compute_similarity(userInput, user_rating_matrix)
  
  # Create dataframe with similarity scores and merge with movie metadata
  correlatedMovies <- data.frame(
    title = names(similarity),
    correlation = similarity,
    row.names = NULL
  )
  reviews <- movie_ratings %>%
    group_by(title) %>%
    summarize(count = n(), mean = round(mean(rating), 1))
  correlatedMovies <- merge(correlatedMovies, reviews, by = "title", all.x = TRUE)
  correlatedMovies <- merge(correlatedMovies, movies, by = "title", all.x = TRUE)
  
  # Filter and sort recommendations
  recommendations <- correlatedMovies %>%
    filter(mean > 3.5 & count > 300 & !(title %in% userInput)) %>%
    arrange(desc(correlation)) %>%
    head(10)
  
  return(recommendations)
}