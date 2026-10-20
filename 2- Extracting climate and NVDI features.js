// Extracting ERA5 climate data and MODIS NDVI using Google Earth Engine

// By Badis Zammouri & Mohamed Chandoul

// OUTPUT: "NVDI_Climate_Features.csv"
// Prodictors:
//   Rain_OctNov
//   Rain_JanMar
//   Temp_Dec
//   Soil
//   NDVI
//   VCI
//   VHI
// Years: 2000-2018

/////////////////////////////////////////////////////////////////////

// 1. Open https://code.earthengine.google.com/

// 2. Upload your Tunisia governorates shapefile to Assets (Use Tunisia_regions)

// 3. Paste the code and run. Then download csv from Google Drive

var governorates = ee.FeatureCollection(
  "projects/cereal-ml/assets/Tunisia_regions"
);

Map.centerObject(governorates, 7);
Map.addLayer(governorates, {}, 'Tunisia Governorates');



// 2. DATASETS


// ERA5-Land Daily Aggregated
// for: rainfall, temperature at 2m and soil moisture
var ERA5 = ee.ImageCollection(
  'ECMWF/ERA5_LAND/DAILY_AGGR'
);


// MODIS Terra NDVI
// MOD13Q1 V6.1 250m 16-day
var MODIS_NDVI = ee.ImageCollection(
  'MODIS/061/MOD13Q1'
);


// MODIS Terra Land Surface Temperature
// MOD11A2 V6.1 1km 8-day
// for VHI
var MODIS_LST = ee.ImageCollection(
  'MODIS/061/MOD11A2'
);



// NVDI quality mask
function maskMODIS(image) {
  var quality = image.select('SummaryQA');

  var good = quality.lte(1);

  return image
    .updateMask(good)
    .select('NDVI')
    .multiply(0.0001)
    .copyProperties(
      image,
      ['system:time_start']
    );
}


// LST quality mask

function maskLST(image) {

  var qc = image.select('QC_Day');

  var mandatoryQA = qc.bitwiseAnd(3);

  var good = mandatoryQA.lte(1);

  return image
    .updateMask(good)
    .select('LST_Day_1km')
    .multiply(0.02)
    .copyProperties(
      image,
      ['system:time_start']
    );
}



// Years
// note: MODIS starts in 02/2000, so the Feb-April 2000 vegetation variables are available

var years = ee.List.sequence(
  2000,
  2018
);


function getSeasonalNDVI(year) {

  year = ee.Number(year);

  return MODIS_NDVI
    .filterDate(
      ee.Date.fromYMD(year, 2, 1),
      ee.Date.fromYMD(year, 5, 1)
    )
    .map(maskMODIS)
    .mean()
    .rename('NDVI')
    .set('year', year);
}


// NVDI climatology
var seasonalNDVI = ee.ImageCollection(
  years.map(getSeasonalNDVI)
);

var NDVI_min = seasonalNDVI
  .min()
  .rename('NDVI_min');

var NDVI_max = seasonalNDVI
  .max()
  .rename('NDVI_max');


// Seasonal LST

function getSeasonalLST(year) {

  year = ee.Number(year);

  return MODIS_LST
    .filterDate(
      ee.Date.fromYMD(year, 2, 1),
      ee.Date.fromYMD(year, 5, 1)
    )
    .map(maskLST)
    .mean()
    .rename('LST')
    .set('year', year);
}




var seasonalLST = ee.ImageCollection(
  years.map(getSeasonalLST)
);

var LST_min = seasonalLST
  .min()
  .rename('LST_min');

var LST_max = seasonalLST
  .max()
  .rename('LST_max');




/////////////////////////////// all predictors for one harvest year

// Rain_OctNov
// Rain_JanMar
// Temp_Dec
// Soil
// NDVI
// VCI
// VHI

function extractYear(year) {

  year = ee.Number(year);

  var previous = year.subtract(1);


  // RAINFALL: OCTOBER-NOVEMBER
  var rainfallON = ERA5
    .filterDate(
      ee.Date.fromYMD(previous, 10, 1),
      ee.Date.fromYMD(previous, 12, 1)
    )
    .select('total_precipitation_sum')
    .sum()
    .multiply(1000)
    .rename('Rain_OctNov');


  // RAINFALL: JANUARY-MARCH
  var rainfallJM = ERA5
    .filterDate(
      ee.Date.fromYMD(year, 1, 1),
      ee.Date.fromYMD(year, 4, 1)
    )
    .select('total_precipitation_sum')
    .sum()
    .multiply(1000)
    .rename('Rain_JanMar');


  // TEMPERATURE: DECEMBER
  var temperature = ERA5
    .filterDate(
      ee.Date.fromYMD(previous, 12, 1),
      ee.Date.fromYMD(year, 1, 1)
    )
    .select('temperature_2m')
    .mean()
    .subtract(273.15)
    .rename('Temp_Dec');


  // SOIL MOISTURE: OCTOBER-NOVEMBER
  var soil = ERA5
    .filterDate(
      ee.Date.fromYMD(previous, 10, 1),
      ee.Date.fromYMD(previous, 12, 1)
    )
    .select('volumetric_soil_water_layer_1')
    .mean()
    .rename('Soil');


  // NDVI: FEBRUARY-APRIL
  var ndvi = MODIS_NDVI
    .filterDate(
      ee.Date.fromYMD(year, 2, 1),
      ee.Date.fromYMD(year, 5, 1)
    )
    .map(maskMODIS)
    .mean()
    .rename('NDVI');


  // VEGETATION CONDITION INDEX VCI = (NDVI - NDVI_min)/(NDVI_max - NDVI_min)

  var VCI = ndvi
    .subtract(NDVI_min)
    .divide(
      NDVI_max.subtract(NDVI_min).add(0.000001)
    )
    .clamp(0, 1)
    .rename('VCI');

  // LST: FEBRUARY-APRIL
  var lst = MODIS_LST
    .filterDate(
      ee.Date.fromYMD(year, 2, 1),
      ee.Date.fromYMD(year, 5, 1)
    )
    .map(maskLST)
    .mean();


  // TEMPERATURE CONDITION INDEX TCI = (LST_max - LST) / (LST_max - LST_min)
  var TCI = LST_max
    .subtract(lst)
    .divide(
      LST_max.subtract(LST_min).add(0.000001)
    )
    .clamp(0, 1)
    .rename('TCI');


  // VEGETATION HEALTH INDEX VHI = 0.5 * VCI + 0.5 * TCI

  var VHI = VCI
    .multiply(0.5)
    .add(
      TCI.multiply(0.5)
    )
    .rename('VHI');


//
  var predictors = ee.Image.cat([
    rainfallON,
    rainfallJM,
    temperature,
    soil,
    ndvi,
    VCI,
    VHI
  ]);



  // GOVERNORATE AVERAGES
  var statistics = predictors.reduceRegions({
    collection: governorates,
    reducer: ee.Reducer.mean(),
    scale: 250,
    tileScale: 4
  });


  // HARVEST YEAR
  statistics = statistics.map(
    function(feature) {

      return feature.set(
        'HarvestYear',
        year
      );

    }
  );


  return statistics;
}


///////////////////////// for all years

var allYears = ee.FeatureCollection(
  years.map(extractYear)
).flatten();



print(
  'Predictor dataset:',
  allYears.limit(20)
);


Export.table.toDrive({

  collection: allYears,

  description:
    'NVDI_Climate_Features.csv',

  fileFormat:
    'CSV'
});



var NDVI2017 = MODIS_NDVI
  .filterDate(
    '2017-02-01',
    '2017-05-01'
  )
  .map(maskMODIS)
  .mean();

Map.addLayer(
  NDVI2017,
  {
    min: 0,
    max: 0.8,
    palette: [
      'white',
      'yellow',
      'green',
      'darkgreen'
    ]
  },
  'NDVI 2017'
);



var VCI2017 = NDVI2017
  .subtract(NDVI_min)
  .divide(
    NDVI_max.subtract(NDVI_min).add(0.000001)
  )
  .clamp(0, 1);

Map.addLayer(
  VCI2017,
  {
    min: 0,
    max: 1,
    palette: [
      'red',
      'yellow',
      'green'
    ]
  },
  'VCI 2017'
);