suppressMessages(library(GenomicRanges))
suppressMessages(library(AnnotationHub))

ah_id <- snakemake@params[["ah_id"]]

ah <- AnnotationHub()
query_data <- subset(ah, preparerclass == "excluderanges")

gr <- query_data[[ah_id]]
gr <- sort(gr)
gr <- keepStandardChromosomes(gr, pruning.mode = "tidy")

write.table(
  as.data.frame(gr),
  file = snakemake@output[[1]],
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE
)
