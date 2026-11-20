

library(ggplot2)
library(moments)



if (!file.exists("model_table.csv")) {
  stop("model_table.csv was not found. Set your working directory to the folder containing the file.")
}

data <- read.csv("model_table.csv", stringsAsFactors = FALSE)

required_columns <- c(
  "governorate", "crop", "harvest_year", "production_1000_qt"
)
missing_columns <- setdiff(required_columns, names(data))

if (length(missing_columns) > 0) {
  stop("Missing required column(s): ", paste(missing_columns, collapse = ", "))
}

data <- data[
  data$crop == "durum_wheat" &
    data$harvest_year >= 2000 &
    data$harvest_year <= 2018,
]

governorates <- c(
  "Ariana", "Ben Arous", "Bizerte", "Béja",
  "Gafsa", "Jendouba", "Kairouan", "Kasserine",
  "Kef", "Mahdia", "Medenine", "Monastir",
  "Nabeul", "Sfax", "Sidi Bouzid", "Siliana",
  "Sousse", "Tunis", "Zaghouan"
)

data <- data[data$governorate %in% governorates, ]

if (nrow(data) == 0) {
  stop(
    "No rows remain after filtering. Check that crop is coded as 'durum_wheat', " ,
    "the year column is numeric, and governorate names match the script."
  )
}



beja <- data[data$governorate == "Béja", ]
beja <- beja[order(beja$harvest_year), ]

valid_rows <- !is.na(beja$harvest_year) &
  !is.na(beja$production_1000_qt)
beja <- beja[valid_rows, ]

production <- beja$production_1000_qt
years <- beja$harvest_year

if (length(production) < 3) {
  stop("Fewer than three valid Béja observations were found. Check the data and governorate spelling.")
}

if (anyDuplicated(years) > 0) {
  stop("More than one Béja observation exists for at least one harvest year. Check for duplicate rows before continuing.")
}

cat("\n============================================================\n")
cat("BEJA DURUM WHEAT PRODUCTION ANALYSIS (2000-2018)\n")
cat("============================================================\n")
cat("Number of valid Béja observations:", length(production), "\n")


beja_stats <- data.frame(
  Statistic = c(
    "Number of observations",
    "Total production",
    "Mean",
    "Median",
    "Standard deviation",
    "Variance",
    "Minimum",
    "Maximum",
    "Range",
    "Coefficient of variation (%)",
    "Skewness",
    "Kurtosis"
  ),
  Value = c(
    length(production),
    sum(production),
    mean(production),
    median(production),
    sd(production),
    var(production),
    min(production),
    max(production),
    diff(range(production)),
    sd(production) / mean(production) * 100,
    moments::skewness(production),
    moments::kurtosis(production)
  )
)

cat("\nDESCRIPTIVE STATISTICS\n")
print(beja_stats, row.names = FALSE, digits = 4)

cat("\nLowest production year:", years[which.min(production)],
    "| Production:", round(min(production), 2), "\n")
cat("Highest production year:", years[which.max(production)],
    "| Production:", round(max(production), 2), "\n")



total_production <- sum(data$production_1000_qt, na.rm = TRUE)
beja_total <- sum(production, na.rm = TRUE)

if (total_production <= 0) {
  stop("The total production denominator is zero or negative; the contribution share cannot be calculated.")
}

beja_percentage <- beja_total / total_production * 100

cat("\nBEJA'S CUMULATIVE CONTRIBUTION\n")
cat("Total production of the 19 selected governorates:",
    round(total_production, 2), "thousand quintals\n")
cat("Béja's total production:",
    round(beja_total, 2), "thousand quintals\n")
cat("Béja's cumulative contribution:",
    round(beja_percentage, 2), "%\n")


skew <- moments::skewness(production)

cat("\nSKEWNESS AND NORMALITY\n")
cat("Skewness:", round(skew, 3), "\n")

if (skew > 0.5) {
  cat("Interpretation: positive skew; the distribution has a longer right tail.\n")
} else if (skew < -0.5) {
  cat("Interpretation: negative skew; the distribution has a longer left tail.\n")
} else {
  cat("Interpretation: approximately symmetric distribution.\n")
}

shapiro_result <- shapiro.test(production)
cat("\nShapiro-Wilk normality test:\n")
print(shapiro_result)

if (shapiro_result$p.value < 0.05) {
  cat("Interpretation: reject normality at the 5% significance level.\n")
} else {
  cat("Interpretation: insufficient evidence to reject normality at the 5% significance level.\n")
}



q1 <- as.numeric(quantile(production, 0.25, type = 7))
q3 <- as.numeric(quantile(production, 0.75, type = 7))
iqr_value <- IQR(production, type = 7)

lower_fence <- q1 - 1.5 * iqr_value
upper_fence <- q3 + 1.5 * iqr_value

outliers <- beja[
  beja$production_1000_qt < lower_fence |
    beja$production_1000_qt > upper_fence,
]

cat("\nOUTLIER ANALYSIS (1.5 x IQR RULE)\n")
cat("Q1:", round(q1, 2), "\n")
cat("Q3:", round(q3, 2), "\n")
cat("IQR:", round(iqr_value, 2), "\n")
cat("Lower outlier boundary:", round(lower_fence, 2), "thousand quintals\n")
cat("Upper outlier boundary:", round(upper_fence, 2), "thousand quintals\n")

if (nrow(outliers) == 0) {
  cat("Potential outliers: none detected.\n")
  cat("Decision: retain all observations. No values fall outside the 1.5 x IQR boundaries.\n")
} else {
  cat("Potential outlier observation(s):\n")
  print(outliers[, c("harvest_year", "production_1000_qt")], row.names = FALSE)
  cat(
    "Decision: do not remove observations automatically. Check the original source and " ,
    "agricultural context before deciding whether any flagged value is an error.\n"
  )
}



trend_test <- cor.test(
  years,
  production,
  method = "spearman",
  exact = FALSE
)

cat("\nSPEARMAN TEMPORAL TREND TEST\n")
print(trend_test)

if (trend_test$p.value < 0.05) {
  cat("Interpretation: a statistically significant monotonic association with year was detected at the 5% level.\n")
} else {
  cat("Interpretation: no statistically significant monotonic association with year was detected at the 5% level.\n")
}



graph_production <- ggplot(
  beja,
  aes(x = harvest_year, y = production_1000_qt)
) +
  geom_line(color = "#A87955", linewidth = 1) +
  geom_point(color = "#5A4030", size = 2.5) +
  geom_smooth(
    method = "lm",
    se = TRUE,
    color = "#9E3030",
    linetype = "dashed"
  ) +
  scale_x_continuous(breaks = 2000:2018) +
  labs(
    title = "Evolution of durum wheat production in Béja",
    subtitle = "Annual production, 2000-2018",
    x = "Harvest year",
    y = "Production (1000 quintals)"
  ) +
  theme_classic(base_size = 12) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(graph_production)



graph_distribution <- ggplot(
  beja,
  aes(x = "Béja", y = production_1000_qt)
) +
  geom_boxplot(
    fill = "#E9C9A7",
    color = "#5A4030",
    width = 0.35,
    outlier.shape = NA
  ) +
  geom_jitter(
    width = 0.08,
    size = 2,
    alpha = 0.7,
    color = "#A87955"
  ) +
  geom_hline(
    yintercept = c(lower_fence, upper_fence),
    linetype = "dashed",
    color = "#9E3030"
  ) +
  labs(
    title = "Distribution of durum wheat production in Béja",
    subtitle = "Annual observations and 1.5 x IQR outlier boundaries, 2000-2018",
    x = NULL,
    y = "Production (1000 quintals)"
  ) +
  theme_classic(base_size = 12) +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank()
  )

print(graph_distribution)
