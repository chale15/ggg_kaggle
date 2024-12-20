library(tidyverse)
library(tidymodels)
library(vroom)
library(glmnet)
library(embed)
library(naivebayes)
library(discrim)
library(themis)
libray(rstanarm)

#Read Data

setwd("~/Desktop/Fall 2024/Stat 348/GitHubRepos/ggg_kaggle")

train <- vroom("train.csv")
test <- vroom("test.csv")

my_recipe <- recipe(type~., data = train) %>% 
  step_mutate_at(color, fn = factor) %>% 
  step_mutate(id, feature = id) %>% 
  step_lencode_glm(all_nominal_predictors(), outcome = vars(type)) %>% 
  step_smote(all_outcomes(), neighbors=3) %>% 
  step_range(all_numeric_predictors(), min=0, max=1)


#Naive Bayes Model

nb_model <- naive_Bayes(Laplace=tune(),
                        smoothness=tune()) %>% 
  set_mode("classification") %>% 
  set_engine("naivebayes")

nb_workflow <- workflow() %>% 
  add_model(nb_model) %>% 
  add_recipe(my_recipe)

tuning_grid <- grid_regular(Laplace(), smoothness(), levels = 20)


folds <- vfold_cv(train, v = 10, repeats=1)

cv_results <- nb_workflow %>% 
  tune_grid(resamples = folds,
            grid = tuning_grid, 
            metrics = metric_set(roc_auc, accuracy))

best_tune <- cv_results %>% select_best(metric='accuracy')

final_workflow <- nb_workflow %>% 
  finalize_workflow(best_tune) %>% 
  fit(data = train)

nb_preds <- predict(final_workflow, 
                    new_data = test,
                    type = 'class')

nb_submission <- nb_preds %>% 
  bind_cols(., test) %>% 
  select(id, .pred_class) %>% 
  rename(type = .pred_class) 


vroom_write(x=nb_submission, file="./Submissions/NBPreds40.csv", delim=",")
