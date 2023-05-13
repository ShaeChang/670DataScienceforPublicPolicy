library(tidyverse)
library(tidymodels)
library(AmesHousing)
library(vip)
library(patchwork)

theme_set(theme_minimal())

# get the Ames housing data
ames <- make_ames()

# create a training and testing split using tidymodels, setting strata = "Sale_Price",
# assign your train and test set
set.seed(123)
split <- initial_split(ames, 
                       prop = 0.7, 
                       strata = "Sale_Price")

ames_train <- training(split)
ames_test <- testing(split)

# create a recipe for the models using all variables as predictors
ames_rec <- 
  recipe(Sale_Price ~ ., data = ames_train) %>%
  # collapse low-frequency categories
  step_other(Neighborhood) %>%
  # dummy encode categorical predictors
  step_dummy(all_nominal_predictors()) %>%
  # center and scale predictors
  step_center(all_predictors()) %>%
  step_scale(all_predictors()) %>%
  # drop near zero variance predictors
  step_nzv(all_predictors()) %>%
  # log10 transform the skewed outcome variable
  step_log(all_outcomes(), base = 10)

# see the engineered training data
bake(prep(ames_rec, training = ames_train), new_data = ames_train)

# set up resampling using 10-fold cross validation
set.seed(20211102)
folds <- vfold_cv(data = ames_train, v = 10, repeats = 1)

# lm ----------------------------------------------------------------------

# create a linear regression model using the "lm" package as the engine
lm_mod <- linear_reg() %>%
  set_engine("lm")

# create a workflow with the recipe and linear regression model you've created
lm_wf <- workflow() %>%
  add_recipe(ames_rec) %>%
  add_model(lm_mod) 

# fit the model by piping your workflow to fit_resamples() by updating the line below
lm_cv <- lm_wf %>%
  fit_resamples(resamples = folds)

# select the best model based on the "rmse" metric
lm_best <- lm_cv %>%
  select_best("rmse")

# use the finalize_workflow() function with your workflow and the best model 
# to update (or "finalize") your workflow by modifying the line below
lm_final <- finalize_workflow(
  lm_wf,
  parameters = lm_best
)

# fit to the training data and extract coefficients
lm_coefs <- lm_final %>%
  fit(data = ames_train) %>%
  extract_fit_parsnip() %>%
  vi(lambda = lasso_best$penalty)

# LASSO -------------------------------------------------------------------

# create a tuning grid for lasso regularization, varying the regularization penalty
lasso_grid <- grid_regular(penalty(), levels = 10)

# create a linear_regression model so that you can tune the penalty parameter
# set the mixture parameter to 1 and use "glmnet" for the engine
lasso_mod <- linear_reg(
  penalty = tune(), 
  mixture = 1
) %>%
  set_engine("glmnet")

# create a workflow using your updated linear regression model you just created and the same recipe
# you defined above
lasso_wf <- workflow() %>%
  add_recipe(ames_rec) %>%
  add_model(lasso_mod) 

# perform hyperparameter tuning using the lasso_grid and the 
# cross_validation folds you created above by modifying the line below
lasso_cv <- lasso_wf %>%
  tune_grid(
    resamples = folds,
    grid = lasso_grid
  )

# select the best model based on the "rmse" metric
lasso_best <- lasso_cv %>%
  select_best(metric = "rmse")

# use the finalize_workflow() function with your lasso workflow and the best model to update (or "finalize") your workflow by modifying the line below
lasso_final <- finalize_workflow(
  lasso_wf,
  parameters = lasso_best
)

# fit to the training data and extract coefficients
lasso_coefs <- lasso_final %>%
  fit(data = ames_train) %>%
  extract_fit_parsnip() %>%
  vi(lambda = lasso_best$penalty) 

# ridge -------------------------------------------------------------------

# create a tuning grid for ridge regularization, varying the regularization penalty
ridge_grid <- grid_regular(penalty(), levels = 10)

# create a linear_regression model so that you can tune the penalty parameter and use "glmnet" for the engine. If you set mixture = 1 for lasso regression above,
# what should you set mixture equal to for ridge regression here?
ridge_mod <- linear_reg(
  penalty = tune(), 
  mixture = 0
) %>%
  set_engine("glmnet")

# create a ridge workflow using your updated linear regression model you just created and 
# the same recipe you defined above
ridge_wf <- workflow() %>%
  add_recipe(ames_rec) %>%
  add_model(ridge_mod)

# perform hyperparameter tuning using the on your ridge hyperparameter grid and
# cross_validation folds you created above by modifying the line below
ridge_cv <- ridge_wf %>%
  tune_grid(
    resamples = folds,
    grid = ridge_grid
  )

# select the best model based on the "rmse" metric
ridge_best <- ridge_fit %>%
  select_best(metric = "rmse")

# use the finalize_workflow() function with your ridge workflow and the best model 
# to update (or "finalize") your workflow
ridge_final <- finalize_workflow(
  ridge_wf,
  parameters = ridge_best
)

# fit the final ridge model to the full training data and extract coefficients
# by updating the line below
ridge_coefs <- ridge_final %>%
  fit(data = ames_train) %>%
  extract_fit_parsnip() %>%
  vi(lambda = ridge_best$penalty) 

# elastic net -------------------------------------------------------------

# create a tuning grid for elastic net regularization, varying the regularization penalty
elastic_net_grid <- grid_regular(penalty(), levels = 10)

# create a linear_regression model so that you can tune the penalty parameter
# and use "glmnet" for the engine. If you set mixture = 1 for lasso regression above,
# and mixture = 0 for ridge regression, what should you set mixture equal to for elastic net?
elastic_net_mod <- linear_reg(
  penalty = tune(), 
  mixture = 0.5
) %>%
  set_engine("glmnet")

# create an elastic net workflow using your updated linear regression model you just created and 
# the same recipe you defined above
elastic_net_wf <- workflow() %>%
  add_recipe(ames_rec) %>%
  add_model(elastic_net_mod)

# perform hyperparameter tuning using the on your elastic net hyperparameter grid and
# cross_validation folds you created above by modifying the line below
elastic_net_fit <- elastic_net_wf %>%
  tune_grid(
    resamples = folds,
    grid = elastic_net_grid
  )

# select the best model based on the "rmse" metric
elastic_net_best <- elastic_net_fit %>%
  select_best(metric = "rmse")

# use the finalize_workflow() function with your elastic net workflow and the best model 
# to update (or "finalize") your workflow
elastic_net_final <- finalize_workflow(
  elastic_net_wf,
  parameters = elastic_net_best
)

# fit the final elastic net model to the full training data and extract coefficients
# by updating the line below
elastic_net_coefs <- elastic_net_final %>%
  fit(data = ames_train) %>%
  extract_fit_parsnip() %>%
  vi(lambda = elastic_net_best$penalty) 

# compare models ----------------------------------------------------------

# the models are comparable for prediction accuracy
bind_rows(
  `lm` = show_best(lm_cv, metric = "rmse", n = 1),
  `LASSO` = show_best(lasso_cv, metric = "rmse", n = 1),
  `ridge` = show_best(ridge_fit, metric = "rmse",n = 1),
  `enet` = show_best(elastic_net_fit, metric = "rmse", n = 1),
  .id = "model"
)

all_coefs <- bind_rows(
  `lm` = lm_coefs,
  `LASSO` = lasso_coefs,
  `ridge` = ridge_coefs,
  `enet` = elastic_net_coefs,
  .id = "model"
) 

all_coefs %>%
  group_by(model) %>%
  slice_max(Importance, n = 10) %>%
  ggplot(aes(Importance, Variable, fill = model)) +
  geom_col(position = "dodge")

all_coefs %>%
  filter(model != "lm") %>%
  group_by(model) %>%
  slice_max(Importance, n = 10) %>%
  ggplot(aes(Importance, Variable, fill = model)) +
  geom_col(position = "dodge")


# compare the regularized coefficients to the lm coefficients for all three models
plot1 <- left_join(
  rename(lm_coefs, lm = Importance),
  rename(lasso_coefs, LASSO = Importance),
  by = "Variable"
) %>%
  ggplot(aes(lm, LASSO)) +
  geom_point(alpha = 0.3) +
  scale_y_continuous(limits = c(0, 0.08))

plot2 <- left_join(
  rename(lm_coefs, lm = Importance),
  rename(ridge_coefs, ridge = Importance),
  by = "Variable"
) %>%
  ggplot(aes(lm, ridge)) +
  geom_point(alpha = 0.3) +
  scale_y_continuous(limits = c(0, 0.08))

plot3 <- left_join(
  rename(lm_coefs, lm = Importance),
  rename(elastic_net_coefs, enet = Importance),
  by = "Variable"
) %>%
  ggplot(aes(lm, enet)) +
  geom_point(alpha = 0.3) +
  scale_y_continuous(limits = c(0, 0.08))

plot1 + plot2 + plot3
