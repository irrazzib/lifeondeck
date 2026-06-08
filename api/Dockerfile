FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ["LifeOnDeck.Api/LifeOnDeck.Api.csproj", "LifeOnDeck.Api/"]
RUN dotnet restore "LifeOnDeck.Api/LifeOnDeck.Api.csproj"
COPY . .
RUN dotnet publish "LifeOnDeck.Api/LifeOnDeck.Api.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "LifeOnDeck.Api.dll"]