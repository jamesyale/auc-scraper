A quick utility to score the best deal on an approved used BMW - beat the dealer using INTERNETS. 

This will take a query string (hard coded, for great justice) and pull the returned car details from the (public) BMW API. It will then save those results to a local database, and on subsiquent imports will only import cars that have changed, for great comparison. 

Run it: `bundle exec ruby auc.rb`

Output some stuff: `curl localhost:4567`

Import new results: `curl localhost:4567/import`