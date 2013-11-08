matchInventoryRings <- function(trees,rings,extractor=from.TreeCode,nyears=30,coredOnly=TRUE){

  ## build tree codes
  names(trees) = toupper(names(trees))
  tree.ID = to.TreeCode(trees$SITE,trees$PLOT,trees$SUB,trees$TAG)

  ## build tree ring codes
  if(is.list(rings)){
    ring.file <- rep(names(rings),times=sapply(rings,ncol))
    rings <- combine.rwl(rings)
  }
  ring.ID <- names(rings)
  ring.info <- extract.stringCode(ring.ID,extractor)

  ## matching up data sets by tree
  mch = match(tree.ID,ring.ID)
  cored = apply(!is.na(trees[,grep("DATE_CORE_COLLECT",names(trees))]),1,any)
  unmatched = which(cored & is.na(mch))
  write.table(tree.ID[unmatched],file="unmatched.txt")
  mch[duplicated(mch)] <- NA  ## if there's multiple stems, match the first

  ## combine data into one table
  combined = cbind(trees,t(as.matrix(rings))[mch,-(nyears-1):0 + nrow(rings)])
  if(coredOnly==TRUE){
    combined = combined[!is.na(combined$"2000"),]
  }
  return(combined)
}