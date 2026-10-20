library(dplyr)
library(ggplot2)

df <- read.csv("model_table.csv")

# 1. Normality Testing (Slide 6.1)
shapiro_results <- df %>%
  group_by(governorate) %>%
  summarise(
    W_statistic = shapiro.test(production_1000_qt)$statistic,
    p_value = shapiro.test(production_1000_qt)$p.value
  ) %>%
  mutate(is_normal = p_value >= 0.05)

print("Shapiro-Wilk Normality Test (First 5):")
print(head(shapiro_results, 5))

# Visual 6.1: Histogram with Normal Density Curve (Proves/Disproves Normality)
ggplot(df, aes(x = production_1000_qt)) +
  geom_histogram(aes(y = ..density..), bins = 30, fill = "steelblue", color = "black", alpha = 0.7) +
  stat_function(fun = dnorm, args = list(mean = mean(df$production_1000_qt, na.rm = TRUE), 
                                         sd = sd(df$production_1000_qt, na.rm = TRUE)), 
                color = "red", size = 1.2) +
  theme_minimal() +
  labs(
    title = "Yield Distribution vs. Theoretical Normal Curve", 
    x = "Production (1000 qt)", 
    y = "Density"
  )

# 2. Spatial Variance Testing (Slide 6.2)
anova_model <- aov(production_1000_qt ~ governorate, data = df)
print("Parametric Spatial Variance (ANOVA F-Statistic):")
print(summary(anova_model))

kruskal_model <- kruskal.test(production_1000_qt ~ governorate, data = df)
print("Non-Parametric Spatial Variance (Kruskal-Wallis H-Statistic):")
print(kruskal_model)

# Visual 6.2: Violin & Jitter Plot (Visualizes Between-Group vs Within-Group Variance)
ggplot(df, aes(x = reorder(governorate, production_1000_qt, FUN = median, na.rm = TRUE), y = production_1000_qt)) +
  geom_violin(trim = FALSE, fill = "lightgray", alpha = 0.5) +
  geom_jitter(width = 0.2, color = "darkblue", alpha = 0.6, size = 1.5) +
  coord_flip() +
  theme_minimal() +
  labs(
    title = "Between-Group Separation vs. Within-Group Spread",
    x = "Governorate",
    y = "Production (1000 qt)"
  ) +
  theme(axis.text.y = element_text(size = 10))