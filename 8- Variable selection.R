library(dplyr)

df <- read.csv("model_table.csv")

df <- df %>%select(-rain_oct_nov_mm, -vci)

write.csv(df, "model_table.csv", row.names = FALSE)