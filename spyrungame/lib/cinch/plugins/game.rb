class Game
  attr_accessor :phase, :user_hash, :playing_user_names, :started, :locations, :actual_location, :spy_user, :votes_needed, :votes, :accused, :accuse_starter, :variants, :clear_hash, :question_answer_log, :players_asked, :last_game_spy_name

  def initialize
    self.phase=:none
    self.user_hash = {}
    self.playing_user_names=[]
    self.started = false
    self.locations = ['Home', 'Jungle', 'Ocean', 'Large City', 'Circus', 'Large Building', 'Cave', 'Village', 'Castle']
    self.actual_location = 'Home'
    self.spy_user=nil
    self.votes_needed=0
    self.votes={}
    self.accuse_starter=nil
    self.accused=nil
    self.variants=[] #finalguess, noaccuse
    self.clear_hash=Hash.new([])
    self.question_answer_log=[]
    self.players_asked=[]
    self.last_game_spy_name=nil
  end

  #add status -- game hasn't started, questioning phase, waiting on __ (accuse phase), waiting on spy to guess location

  def add_user(user)
    user_hash[user.nick]=user unless user_hash.has_key?(user.nick)
  end

  def remove_user(user)
    user_hash.delete(user.nick)
  end

  def setup_game
    self.started=true
    self.phase=:main
    self.playing_user_names=self.user_hash.keys.shuffle
    self.spy_user=self.user_hash[self.playing_user_names.first]
    self.actual_location=self.locations.shuffle.first
    #self.votes_needed=self.playing_user_names.length/2+1
    self.votes_needed=self.playing_user_names.length-1 #change to all but one person must vote for them
  end

  def all_votes_in?
    puts '==Current votes =='
    puts self.votes
    self.votes.size==self.players_joined
    #return
  end

  def most_voted_player_with_enough
    counts=Hash.new(0)
    counts['']=0
    puts "== Checking votes for #{playing_user_names.size} players =="
    puts self.playing_user_names
    puts '== =='

    self.playing_user_names.each do |name|
      #puts "Player #{name} voted"
      target_name=self.votes[name]
      puts "#{name} voted for #{target_name}"
      counts[target_name]+=1 unless target_name.nil? or target_name==''
    end
    puts '=====Grouped votes=====\n'
    puts counts
    puts '\n'
    puts '================\n'
    most_voted_player_name=self.playing_user_names.sort_by{|player_name| -counts[player_name]}.first
    puts most_voted_player_name
    puts '================\n'
    most_voted_player_name=nil if counts[most_voted_player_name]<self.votes_needed
    #returns most_voted_player_name
    return most_voted_player_name
  end

  def correct_caps_players(player_name) #returns nil if none
    self.playing_user_names.select{|list_name| player_name.casecmp(list_name)==0}.first
  end

  def player_during_main_phase?(player_name)
    self.started && self.playing_user_names.include?(player_name) && self.phase==:main
  end

  #def player_during_accusing_phase?(player_name)
  #  self.started && self.playing_user_names.include?(player_name) && self.phase==:accusing
  #end

  def user_in_started_game?(input_user)
    self.started && self.playing_user_names.include?(input_user.nick)
  end

  def players_joined
    self.user_hash.length
  end

  def toggle_variant(input_variant)
    on_after=!self.variants.include?(input_variant)
    if on_after
      self.variants.push(input_variant)
    else
      self.variants.delete(input_variant)
    end
  end
end
