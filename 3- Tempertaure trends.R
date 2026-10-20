library(dplyr)
library(ggplot2)

df <- read.csv("model_table.csv")

temp_lm <- lm(temp_dec_c ~ harvest_year, data = df)
print(summary(temp_lm))

df <- df %>%
  mutate(decade_regime = ifelse(harvest_year <= 2009, "2000-2009", "2010-2018"))

welch_test <- t.test(temp_dec_c ~ decade_regime, data = df, var.equal = FALSE)
print(welch_test)

yearly_temp <- df %>%
  group_by(harvest_year) %>%
  summarise(
    mean_t = mean(temp_dec_c, na.rm = TRUE),
    sd_t = sd(temp_dec_c, na.rm = TRUE)
  )

ggplot(yearly_temp, aes(x = harvest_year, y = mean_t)) + geom_line(color = "firebrick", linewidth = 1) +
  geom_smooth(method = "lm", se = FALSE, color = "red", linetype = "dashed", linewidth = 0.9) +
  scale_x_continuous(breaks = seq(2000, 2018, by = 2)) +
  theme_minimal() +
  labs(
    title = "Evolution of December Temperature (2000-2018)",
    x = "Harvest Year",
    y = "December Mean Temp (°C)"
  )