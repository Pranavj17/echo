  ---
  🚀 Ready to Run - Final Steps

  cd /Users/pranav/Documents/echo

  # 1. Clean build EVERYTHING (CRITICAL!)
  cd shared && rm -rf _build && mix clean && mix compile
  cd ../agents/ceo && rm -rf _build && mix clean && mix compile && mix escript.build
  cd ../cto && rm -rf _build && mix clean && mix compile && mix escript.build
  cd ../chro && rm -rf _build && mix clean && mix compile && mix escript.build
  cd ../product_manager && rm -rf _build && mix clean && mix compile && mix escript.build
  cd ../senior_architect && rm -rf _build && mix clean && mix compile && mix escript.build
  cd ../operations_head && rm -rf _build && mix clean && mix compile && mix escript.build
  cd ../..

  # 2. Verify containers
  docker-compose ps

  # 3. Run training
  ./day2_training_v2.sh

  ---