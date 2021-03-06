###
# 1 IDW raster map (with boundary overlay for context)
###

# By: Yao Xen Tan, Isaac Kamber updated by M. Kolak
# Created: 3/25/19, updated 4/28/2019

rm(list=ls())

setwd("~/Downloads/repm2andpm10aggregation")

library("sp")
library("rgdal")
library("rgeos")
library(raster)
library(adehabitatHR)
library(tmap)
library(data.table)
library(gstat)
library(xts)

#######################################
# PM10 data
#######################################

EPA.Points <- readOGR(".", "PM10YearlyShapefile")
str(EPA.Points@data)
EPA.Points@data
plot(EPA.Points)

#Take out far points
test <- EPA.Points
test<- test[-c(8), ]
str(test@data)
plot(test)
EPA.Points <- test

# IDW
# define sample grid based on the extent of the EPA.Points file
grid <-spsample(EPA.Points, type = 'regular', n = 10000)

# runs the idw for the variable of interest in EPA.Points
idw <- idw(EPA.Points$X17_DMPC ~ 1, EPA.Points, newdata = grid)

idw.output = as.data.frame(idw)
names(idw.output)[1:3] <- c("long", "lat", "prediction")

# create spatial points data frame
spg <- idw.output
coordinates(spg) <- ~ long + lat

# coerce to SpatialPixelsDataFrame
gridded(spg) <- TRUE
# coerce to raster
raster_idw <- raster(spg)

# sets projection to British National Grid
projection(raster_idw) <- CRS("+init=epsg:4326")

# mask raster by Chicago polygon file
masked_idw <- mask(raster_idw, Chicago)
# masked_idw <- mask(raster_idw, Output.Areas)  #if want ALL of 3 counties total area

# plot masked raster 
tm_shape(masked_idw) + tm_raster("prediction", style = "quantile", n = 100, legend.show = FALSE)

# plot masked raster with point emissions
# SAVE FOR REPORT
tm_shape(masked_idw, bbox=masked_idw) + tm_raster("prediction", style = "quantile", n = 100, legend.show = FALSE) +
  tm_shape(EPA.Points) + 
  tm_bubbles(size = "X17_DMPC", col = "X17_DMPC", 
             palette = "Blues", scale = 0.5, 
             style = "quantile", legend.size.show = FALSE, 
             title.col = "2017 PM 10 Mean Concentration") 

# plot masked raster with Community Area overlay
# SAVE FOR REPORT
tm_shape(masked_idw, bbox=Chicago) + 
  tm_raster("prediction", style = "quantile", n = 5, legend.show = TRUE, title = "PM 10 prediction") + 
  tm_shape(Chicago) + tm_borders(alpha=.5,) + 
  tm_layout(frame = F, legend.position = c("left","bottom"))

# Extracting the Pixel Values from the Raster
#Extract all values for chicago Community Areas
chi.ave <- raster::extract(masked_idw, Chicago)
head(chi.ave)
str(chi.ave)

#Remove na values
chi.ave <- lapply(chi.ave, na.omit)

#Calculating Average Value by Community Area
#Mean value by CA
ca.ave <- lapply(chi.ave, FUN=mean)
ca.ave  <- unlist(ca.ave )

# Attach Mean Values to Community Area Information
#Grab Community Area names/numbers from Chicago shapefile 
chi.info <- cbind(as.integer(as.character(Chicago@data$area_numbe)))
head(chi.info)

#Attach EPA Ave numbers
chica.final <- cbind(chi.info, ca.ave)
colnames(chica.final) <- c("area_numbe", "PM10")
as.data.frame(chica.final)

Chicago<- merge(Chicago, chica.final, by = "area_numbe")
head(Chicago@data)

# plot masked raster with Community Area overlay
# SAVE FOR REPORT
tm_shape(Chicago) + 
  tm_fill("PM10", style = "quantile", n = 5, legend.show = TRUE, title = "PM10 by CA") + 
  tm_shape(Chicago) + tm_borders(alpha=.5,) + 
  tm_layout(frame = F, legend.position = c("left","bottom"))
