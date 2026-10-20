library(dplyr)
library(ggcorrplot)

df <- read.csv("model_table_og.csv")

cor_vars <- df %>%
  select(production_1000_qt, temp_dec_c, rain_oct_nov_mm, sm_oct_nov, rain_jan_mar_mm, ndvi_mean, vci, vhi) %>%
  rename(
    Production = production_1000_qt,
    Temp_Dec = temp_dec_c,
    Rain_Autumn = rain_oct_nov_mm,
    Soil_Autumn = sm_oct_nov,
    Rain_Spring = rain_jan_mar_mm,
    NDVI = ndvi_mean,
    VCI = vci,
    VHI = vhi
  )

corr_matrix <- cor(cor_vars, use = "complete.obs")

ggcorrplot(corr_matrix, 
           hc.order = FALSE, 
           type = "lower", 
           lab = TRUE, 
           lab_size = 4, 
           colors = c("firebrick", "white", "steelblue"), 
           title = "Correlation matrix & Multicollinearity Check", 
           ggtheme = ggplot2::theme_minimal())