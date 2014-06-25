decomp <- function(x,transform=TRUE)
{
        # install.packages("forecast")
        require(forecast)
        # Transform series
        if(transform & min(x,na.rm=TRUE) >= 0)
        {
                lambda <- BoxCox.lambda(na.contiguous(x))
                x <- BoxCox(x,lambda)
        }
        else
        {
                lambda <- NULL
                transform <- FALSE
        }
        # Seasonal data
        if(frequency(x)>1)
        {
                x.stl <- stl(x,s.window="periodic",na.action=na.contiguous)
                trend <- x.stl$time.series[,2]
                season <- x.stl$time.series[,1]
                remainder <- x - trend - season
        }
        else #Nonseasonal data
        {
                require(mgcv)
                tt <- 1:length(x)
                trend <- rep(NA,length(x))
                trend[!is.na(x)] <- fitted(gam(x ~ s(tt)))
                season <- NULL
                remainder <- x - trend
        }
        return(list(x=x,trend=trend,season=season,remainder=remainder,
                    transform=transform,lambda=lambda))
}

