library(simulatr)

parameter_grid <- data.frame(
  n = c(25, 50, 75, 100),      # sample size
  p = 15,                      # dimension
  s = 5,                       # number of nonzero coefficients
  beta_val = 3                 # value of nonzero coefficients
)

get_ground_truth <- function(p, s, beta_val){
  beta <- numeric(p)
  beta[1:s] <- beta_val
  list(beta = beta)
}

parameter_grid <- parameter_grid |> add_ground_truth(get_ground_truth)

fixed_parameters <- list(
  B = 20,                      # number of data realizations
  seed = 4                    # seed to set prior to generating data and running methods
)

# define data-generating model based on the Gaussian linear model
generate_data_f <- function(n, p, ground_truth){
  X <- matrix(rnorm(n*p), n, p, dimnames = list(NULL, paste0("X", 1:p)))
  y <- X %*% ground_truth$beta + rnorm(n)
  data <- list(X = X, y = y)
  data
}
# need to call simulatr_function() to give simulatr a few more pieces of info
generate_data_function <- simulatr_function(
  f = generate_data_f,                        
  arg_names = formalArgs(generate_data_f),    
  loop = TRUE
)

# ordinary least squares
ols_f <- function(data){
  X <- data$X
  y <- data$y
  lm_fit <- lm(y ~ X - 1)
  beta_hat <- coef(lm_fit)
  results <- list(beta = unname(beta_hat))
  results
}

# lasso
lasso_f <- function(data){
  X <- data$X
  y <- data$y
  glmnet_fit <- glmnet::cv.glmnet(x = X, y = y, nfolds = 5, intercept = FALSE)
  beta_hat <- glmnet::coef.glmnet(glmnet_fit, s = "lambda.1se")
  results <- list(beta = beta_hat[-1])
  results
}

# create simulatr functions
ols_spec_f <- simulatr_function(f = ols_f, arg_names = character(0), loop = TRUE)
lasso_spec_f <- simulatr_function(f = lasso_f, arg_names = character(0), loop = TRUE)
run_method_functions <- list(ols = ols_spec_f, lasso = lasso_spec_f)

rmse <- function(output, ground_truth) {
  sqrt(sum((output$beta - ground_truth$beta)^2))
}

evaluation_functions <- list(rmse = rmse)
    
simulatr_spec <- simulatr_specifier(
  parameter_grid,
  fixed_parameters,
  generate_data_function, 
  run_method_functions,
  evaluation_functions
)

saveRDS(simulatr_spec, "sim_spec_obj.rds")
