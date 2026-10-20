library(dplyr)
library(ggplot2)

df <- read.csv("model_table.csv")

# Isolate the top 3 governorates by median production
top_3_govs <- c("Béja", "Jendouba", "Siliana")
df_top <- df %>% filter(governorate %in% top_3_govs)

# Generate a 3-panel side-by-side chart (facet_wrap)
ggplot(df_top, aes(x = harvest_year, y = production_1000_qt, fill = governorate)) +
  geom_line(color = "steelblue", linewidth = 1) +
  geom_point(color = "darkblue", size = 2) +
  # Add the OLS trendline to each specific governorate
  geom_smooth(method = "lm", se = FALSE, color = "red", linetype = "dashed", linewidth = 1) +
  facet_wrap(~governorate, ncol = 3, scales = "free_y") +
  theme_minimal() +
  labs(
    title = "Contradictory Raw Yield Trends in Top Producing Regions (2000-2018)",
    x = "Harvest Year",
    y = "Production (1000 qt)"
  ) +
  theme(
    legend.position = "none",
    strip.text = element_text(size = 14, face = "bold"),
    panel.spacing = unit(2, "lines")
  )