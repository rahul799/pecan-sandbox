#--------------------------------------------------------------------------------------------------#
# Functions to prepare and write out ED2.2 config.xml files for MA, SA, and Ensemble runs
#--------------------------------------------------------------------------------------------------#


#--------------------------------------------------------------------------------------------------#
PREFIX_XML <- '<?xml version="1.0"?>\n<!DOCTYPE config SYSTEM "ed.dtd">\n'

### TODO: Update this script file to use the database for setting up ED2IN and config files
#--------------------------------------------------------------------------------------------------#


#--------------------------------------------------------------------------------------------------#
##' Abbreviate run id to ed limits
##'
##' As is the case with ED, input files must be <32 characters long.
##' this function abbreviates run.ids for use in input files. Depreciated.
##' @param run.id string indicating nature of the run
##' @export
##' @author unknown
#--------------------------------------------------------------------------------------------------#
abbreviate.run.id.ED <- function(run.id){
  run.id <- gsub('tundra.', '', run.id)
  run.id <- gsub('ebifarm.', '', run.id)
  run.id <- gsub('deciduous', 'decid', run.id)
  run.id <- gsub('evergreen', 'everg', run.id)
  run.id <- gsub('_', '', run.id)
  run.id <- gsub('root', 'rt', run.id)
  run.id <- gsub('water', 'h2o', run.id)
  run.id <- gsub('factor', '', run.id)
  run.id <- gsub('turnover', 'tnvr', run.id)
  run.id <- gsub('mortality', 'mort', run.id)
  run.id <- gsub('conductance', 'cond', run.id)
  run.id <- gsub('respiration', 'resp', run.id)
  run.id <- gsub('stomatalslope', 'stmslope', run.id)
  run.id <- gsub('nonlocaldispersal', 'nldisprs', run.id)
  run.id <- gsub('quantumefficiency', 'quantef', run.id)
  return(run.id)
}
#==================================================================================================#


#--------------------------------------------------------------------------------------------------#
##' convert parameters from PEcAn database default units to ED defaults
##' 
##' Performs model specific unit conversions on a a list of trait values,
##' such as those provided to write.config
##' @title Convert samples for ed
##' @param trait.samples a matrix or dataframe of samples from the trait distribution
##' @return matrix or dataframe with values transformed
##' @author Shawn Serbin, David LeBauer, Carl Davidson
convert.samples.ED <- function(trait.samples){
  DEFAULT.LEAF.C <- 0.48
  DEFAULT.MAINTENANCE.RESPIRATION <- 1/2
  ## convert SLA from m2 / kg leaf to m2 / kg C 
    
  if('SLA' %in% names(trait.samples)){
    sla <- trait.samples[['SLA']]
    trait.samples[['SLA']] <- sla / DEFAULT.LEAF.C
  }
  
  ## convert leaf width / 1000
  if('leaf_width' %in% names(trait.samples)){
    lw <- trait.samples[['leaf_width']]
    trait.samples[['leaf_width']] <- lw / 1000.0
  }
  
  if('root_respiration_rate' %in% names(trait.samples)) {
    rrr1 <- trait.samples[['root_respiration_rate']]
    rrr2 <-  rrr1 * DEFAULT.MAINTENANCE.RESPIRATION
    trait.samples[['root_respiration_rate']] <- arrhenius.scaling(rrr2, old.temp = 25, 
                                                                  new.temp = 15)
  }
  
  if('Vcmax' %in% names(trait.samples)) {
    vcmax <- trait.samples[['Vcmax']]
    trait.samples[['Vcmax']] <- arrhenius.scaling(vcmax, old.temp = 25, new.temp = 15)
  }

   ### Convert leaf_respiration_rate_m2 to dark_resp_factor
   if('leaf_respiration_rate_m2' %in% names(trait.samples)) {
      leaf_resp = trait.samples[['leaf_respiration_rate_m2']]
      vcmax <- trait.samples[['Vcmax']]
    
      ### First scale variables to 15 degC
      trait.samples[['leaf_respiration_rate_m2']] <- 
        arrhenius.scaling(leaf_resp, old.temp = 25, new.temp = 15)
      vcmax_15 <- arrhenius.scaling(vcmax, old.temp = 25, new.temp = 15)
    
      # need to add back dark resp prior?? no?
    
      ### Calculate dark_resp_factor
      trait.samples[['dark_respiration_factor']] <- trait.samples[['leaf_respiration_rate_m2']]/
        vcmax_15
      
      ### Remove leaf_respiration_rate from trait samples
      remove <- which(names(trait.samples)=='leaf_respiration_rate_m2')
      trait.samples = trait.samples[-remove]
      
   } ### End dark_respiration_factor loop
   
  
  return(trait.samples)
}
#==================================================================================================#


#--------------------------------------------------------------------------------------------------#
##' Writes an xml and ED2IN config files for use with the Ecological Demography model.
##'
##' Requires a pft xml object, a list of trait values for a single model run,
##' and the name of the file to create
##' @title Write ED configuration files
##' @param pft 
##' @param trait.samples vector of samples for a given trait
##' @param settings list of settings from pecan settings file
##' @param outdir directory for config files to be written to
##' @param run.id id of run
##' @return configuration file and ED2IN namelist for given run
##' @export
##' @author David LeBauer, Shawn Serbin, Carl Davidson
#--------------------------------------------------------------------------------------------------#
write.config.ED2 <- function(defaults, trait.values, settings, outdir, run.id){

  ### Get ED2 specific model settings and put into output config xml file
  xml <- listToXml(settings$run$model$config.header, 'config')
  names(defaults) <- sapply(defaults,function(x) x$name)
  
  for(group in names(trait.values)){
    if(group == "env"){
      
      ## set defaults from config.header
      
      ##
      
    } else {
      ##is a PFT
      pft <- defaults[[group]]
      ### Insert PFT names into output xml file
      #pft.xml <- xmlNode('pft',listToXml(pft$name,"name"))
      ### Insert PFT constants into output xml file  
      pft.xml <- listToXml(pft$constants, 'pft')
      #constants <- listToXml(pft$constants,'')
      #pft.xml <- append.xmlNode(pft.xml,pft$constants)
      #pft.xml <- append.xmlNode(pft.xml, constants)
      
      ## copy values
      if(!is.null(trait.values[[group]])){
        vals <- convert.samples.ED(trait.values[[group]])
        names(vals) <- droplevels(trait.dictionary(names(vals))$model.id)
        for(trait in names(vals)){
          pft.xml <- append.xmlNode(pft.xml, 
              xmlNode(trait, vals[trait]))
        }
      }
      xml <- append.xmlNode(xml, pft.xml)
    }
  }
    
  xml.file.name <-paste('c.',run.id,sep='')  
  if(nchar(xml.file.name) >= 512)  # was 128.  Changed in ED to 512
    stop(paste('The file name, "',xml.file.name,
            '" is too long and will cause your ED run to crash ',
            'if allowed to continue. '))
  saveXML(xml, file = paste(outdir, xml.file.name, sep=''), 
      indent=TRUE, prefix = PREFIX_XML)
  
  startdate <- as.Date(settings$run$start.date)
  enddate <- as.Date(settings$run$end.date)
  
  #-----------------------------------------------------------------------
  ### Edit ED2IN file for runs
  ed2in.text <- readLines(con=settings$run$model$edin, n=-1)
  
  ed2in.text <- gsub('@SITE_LAT@', settings$run$site$lat, ed2in.text)
  ed2in.text <- gsub('@SITE_LON@', settings$run$site$lon, ed2in.text)
  ed2in.text <- gsub('@SITE_MET@', settings$run$site$met, ed2in.text)
  ed2in.text <- gsub('@MET_START@', settings$run$site$met.start, ed2in.text)
  ed2in.text <- gsub('@MET_END@', settings$run$site$met.end, ed2in.text)
  ed2in.text <- gsub('@SITE_PSSCSS@', settings$run$site$psscss, ed2in.text)
  
  if(settings$run$model$phenol.scheme==1){
    # Set prescribed phenology switch in ED2IN
	  ed2in.text <- gsub(' @PHENOL_SCHEME@', settings$run$model$phenol.scheme, ed2in.text)
	  # Phenology filename
  	ed2in.text <- gsub('@PHENOL@', settings$run$model$phenol, ed2in.text)
	  # Set start year of phenology
  	ed2in.text <- gsub('@PHENOL_START@', settings$run$model$phenol.start, ed2in.text)
	  # Set end year of phenology
  	ed2in.text <- gsub('@PHENOL_END@', settings$run$model$phenol.end, ed2in.text)
	
	  # If not prescribed set alternative phenology scheme.
    } else {
	  ed2in.text <- gsub(' @PHENOL_SCHEME@', settings$run$model$phenol.scheme, ed2in.text)
    }
  
    #-----------------------------------------------------------------------
    ed2in.text <- gsub('@ED_VEG@', settings$run$model$veg, ed2in.text)
    ed2in.text <- gsub('@ED_SOIL@', settings$run$model$soil, ed2in.text)
    ed2in.text <- gsub('@ED_INPUTS@', settings$run$model$inputs, ed2in.text)

    #-----------------------------------------------------------------------
    ed2in.text <- gsub('@START_MONTH@', format(startdate, "%m"), ed2in.text)
    ed2in.text <- gsub('@START_DAY@', format(startdate, "%d"), ed2in.text)
    ed2in.text <- gsub('@START_YEAR@', format(startdate, "%Y"), ed2in.text)
    ed2in.text <- gsub('@END_MONTH@', format(enddate, "%m"), ed2in.text)
    ed2in.text <- gsub('@END_DAY@', format(enddate, "%d"), ed2in.text)
    ed2in.text <- gsub('@END_YEAR@', format(enddate, "%Y"), ed2in.text)

    #-----------------------------------------------------------------------
    ed2in.text <- gsub('@OUTDIR@', settings$run$host$outdir, ed2in.text)
    ed2in.text <- gsub('@ENSNAME@', run.id, ed2in.text)
    ed2in.text <- gsub('@CONFIGFILE@', xml.file.name, ed2in.text)
  
    ### Generate a numbered suffix for scratch output folder.  Useful for cleanup.  TEMP CODE. NEED TO UPDATE.
    #cnt = counter(cnt) # generate sequential scratch output directory names 
    #print(cnt)
    #scratch = paste(Sys.getenv("USER"),".",cnt,"/",sep="")
    scratch = Sys.getenv("USER")
    #ed2in.text <- gsub('@SCRATCH@', paste('/scratch/', settings$run$scratch, sep=''), ed2in.text)
    ed2in.text <- gsub('@SCRATCH@', paste('/scratch/', scratch, sep=''), ed2in.text)
    ###
  
    ed2in.text <- gsub('@OUTFILE@', paste('out', run.id, sep=''), ed2in.text)
    ed2in.text <- gsub('@HISTFILE@', paste('hist', run.id, sep=''), ed2in.text)
 
    #-----------------------------------------------------------------------
    ed2in.file.name <- paste('ED2INc.',run.id, sep='')
    writeLines(ed2in.text, con = paste(outdir, ed2in.file.name, sep=''))
    
    ### Display info to the console.
    print(run.id)
}
#==================================================================================================#


#--------------------------------------------------------------------------------------------------#
##'
##' @name write.run.ED
##' @title Function to generate ED2.2 model run script files
##' @author <unknown>
##' @import PEcAn.utils
#--------------------------------------------------------------------------------------------------#
write.run.ED <- function(settings){
  run.script.template = system.file("inst", "run.template.ED", package="PEcAn.ED")
  run.text <- scan(file = run.script.template, 
                   what="character",sep='@', quote=NULL, quiet=TRUE)
  run.text  <- gsub('TMP', paste("/scratch/",Sys.getenv("USER"),sep=""), run.text)
  run.text  <- gsub('BINARY', settings$run$host$ed$binary, run.text)
  run.text <- gsub('OUTDIR', settings$run$host$outdir, run.text)
  runfile <- paste(settings$outdir, 'run', sep='')
  writeLines(run.text, con = runfile)
  if(settings$run$host$name == 'localhost') {
    system(paste('cp ', runfile, settings$run$host$rundir))
  }else{
    system(paste("rsync -outi ", runfile , ' ', settings$run$host$name, ":",
                 settings$run$host$rundir, sep = ''))
  }
}
#==================================================================================================#


#--------------------------------------------------------------------------------------------------#
##' Clear out old config and ED model run files.
##'
##' @name remove.config
##' @return nothing, removes config files as side effect
##' @export
##' @author Shawn Serbin, David LeBauer
remove.config <- function(main.outdir,settings) {
  #if(FALSE){
    todelete <- dir(unlist(main.outdir), pattern = 'ED2INc.*',
                    recursive=TRUE, full.names = TRUE)
    if(length(todelete>0)) file.remove(todelete)
    rm(todelete)
    
    #todelete <- dir(unlist(main.outdir), pattern = "c.*",
    #                recursive=TRUE, full.names = TRUE)
    
    ### Other code wasn't working properly.  This won't recurse however.
    # TODO: Fix this code so it finds the correct files and will recurse
    todelete <- Sys.glob(file.path(unlist(main.outdir), "c.*") )
    if(length(todelete>0)) file.remove(todelete)
    rm(todelete)

    filename.root <- get.run.id('c.','*')  # TODO: depreciate abbrev run ids
  
    if(settings$run$host$name == 'localhost'){
      if(length(dir(settings$run$host$rundir, pattern = filename.root)) > 0) {
        todelete <- dir(settings$run$host$outdir,
                        pattern = paste(filename.root, "*[^log]", sep = ''), 
                        recursive=TRUE, full.names = TRUE)
        file.remove(todelete)
      }
    } else {
      files <- system(paste("ssh ", settings$run$host$name, " 'ls ", 
                            settings$run$host$rundir, "*", 
                            filename.root, "*'", sep = ''), intern = TRUE)
      if(length(files) > 0 ) {
        todelete <- files[-grep('log', files)]
        system(paste("ssh -T ", settings$run$host$name,
                    " 'for f in ", paste(todelete, collapse = ' '),"; do rm $f; done'",sep=''))
        }
      }
    #}
}
#==================================================================================================#


####################################################################################################
### EOF.  End of R script file.            	
####################################################################################################