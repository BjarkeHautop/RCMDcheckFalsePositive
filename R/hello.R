filter <- function() {
  message("This is a custom filter function.")
}

DataProcessor <- R6::R6Class(
  "DataProcessor",
  public = list(
    data = NULL,
    initialize = function(data) self$data <- data,

    filter_data = function(data) {
      filter()
      self$data <- stats::filter(self$data, rep(1, 3))
    }
  )
)
