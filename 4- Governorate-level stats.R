library(dplyr)
library(moments)
library(ggplot2)

df <- read.csv("model_table.csv")

gov_stats <- df %>%
  group_by(governorate) %>%
  summarise(
    n_years = n(),
    mean_prod = mean(production_1000_qt, na.rm = TRUE),
    median_prod = median(production_1000_qt, na.rm = TRUE),
    var_prod = var(production_1000_qt, na.rm = TRUE),
    sd_prod = sd(production_1000_qt, na.rm = TRUE),
    skew_prod = skewness(production_1000_qt, na.rm = TRUE),
    kurt_prod = kurtosis(production_1000_qt, na.rm = TRUE)
  ) %>%
  arrange(desc(median_prod))

print(head(gov_stats, 3))
print(tail(gov_stats, 3))

ggplot(df, aes(x = reorder(governorate, production_1000_qt, FUN = median, na.rm = TRUE), y = production_1000_qt)) +
  geom_boxplot(fill = "steelblue", color = "black", outlier.color = "red", outlier.size = 2) +
  coord_flip() +
  theme_minimal() +
  labs(
    title = "Durum Wheat Production Distribution by Governorate (2000-2018)",
    x = "Governorate",
    y = "Production (1000 qt)"
  ) +
  theme(axis.text.y = element_text(size = 10))