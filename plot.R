library(ggplot2)
library(reshape)

args<-commandArgs(trailingOnly=T)
title<-strsplit(args[1], '.', fixed=T)[[1]][1]
l<-list()
for (f in args){
	n<-tail(strsplit(f, '.', fixed=T)[[1]], n=1)
	l[[n]]<-read.csv(f, header=F)[[1]]
}
df<-data.frame(l)
mdf<-melt(df, id='iteration')
ggplot(mdf, aes(x=iteration, y=value, color=variable)) +
	geom_point() +
	geom_line() +
	scale_y_continuous(breaks=seq(0, 400, 5), limits=c(160,340)) +
	ggtitle(title)
save_file<-paste0(title, '.png')
ggsave(save_file, device='png', width=9, heigh=6)
print(save_file)
