require 'rubygems'
require 'sinatra'

set :sessions, true

BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17
CHIPS_AMOUNT = 500

helpers do
  def calculate_total(cards)
    arr = cards.map {|element| element[1]}
    amount = 0
    arr.each do |a|
      if a == 'Ace'
        amount += 11
      else 
        amount += a.to_i == 0 ? 10 : a.to_i
      end
    end

    arr.select {|element| element == "Ace"}.count.times do
      break if amount <= BLACKJACK_AMOUNT
      amount -= 10
    end

    amount
  end

  def card_image(card)
    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
    end

    value = card[1]
    if ['J', 'Q', 'K', 'Ace'].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'Ace' then 'ace'
      end  
    end 
    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
    @play_again = true
    @show_hit_or_stay_bottons = false
    @winner = "<strong>#{session[:player_name]} wins!</strong> #{msg} You win $#{session[:player_bet]}"
    session[:player_chips_amount] += session[:player_bet]
  end

  def loser!(msg)
    @show_hit_or_stay_bottons = false
    session[:player_chips_amount] -= session[:player_bet]
    @loser = "<strong>#{session[:player_name]} loses...</strong> #{msg} You lose $#{session[:player_bet]}"

    if session[:player_chips_amount] <= 0
      @no_more_chips = true
    else
      @play_again = true
    end
  end

  def tie!(msg)
    @play_again = true
    @show_hit_or_stay_bottons = false
    @winner = "<strong>It's a tie!</strong> #{msg}"
  end

end

before do
  @show_hit_or_stay_bottons = true
end

get '/' do
  session[:player_chips_amount] = CHIPS_AMOUNT
  erb :new_player
end

post '/' do
  if params[:player_name].empty?
    @error = "Name is required."
    halt erb(:new_player)
  end

  session[:player_name] = params[:player_name]
  #redirect '/game'
  redirect '/place_bet'
end

get '/place_bet' do
  session[:player_bet] = nil
  erb :bet
end

post '/place_bet' do
  bet_amount = params[:bet]
  if bet_amount.empty? || bet_amount.to_i == 0
    @error = "Must bet some money."
    halt erb(:bet)
  elsif bet_amount.to_i > session[:player_chips_amount]
    @error = "The greatest amount of chips you can bet is $#{session[:player_chips_amount]}"
    halt erb(:bet)
  else
    session[:player_bet] = bet_amount.to_i
    redirect '/game'
  end
end

post '/bet/change' do
  session[:player_chips_amount] = CHIPS_AMOUNT
  redirect '/place_bet'
end

get '/game' do
  session[:turn] = session[:player_name]
  #create a deck and put it in session
  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'Ace']
  session[:deck] = suits.product(values).shuffle!
  #deal card
  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK_AMOUNT
    winner!("#{session[:player_name]} hit blackjack.")
  end

  erb :game
end

#hit
post '/game/player/hit' do 
  session[:player_cards] << session[:deck].pop
  
  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK_AMOUNT
    winner!("#{session[:player_name]} hit blackjack.")
  elsif player_total > BLACKJACK_AMOUNT
    loser!("#{session[:player_name]} busted at #{player_total}.")
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  @success = "#{session[:player_name]} has chosen to stay."
  @show_hit_or_stay_bottons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_or_stay_bottons = false

  #decision tree
  dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total == BLACKJACK_AMOUNT
    loser!("Dealer hit blackjack.")
  elsif dealer_total > BLACKJACK_AMOUNT 
    winner!("Dealer busted at #{dealer_total}.")
  elsif dealer_total >= DEALER_MIN_HIT
    #dealer stay
    redirect '/game/compare'
  else
    #dealer hit
    @press_dealing = true
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_hit_or_stay_bottons = false

  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total < dealer_total
    loser!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}.")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}.")
  else
    tie!("Both #{session[:player_name]} and the dealer stayed at #{player_total}.")
  end

  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end