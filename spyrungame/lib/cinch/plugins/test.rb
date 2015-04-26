
def do_list(in_list,player_name)
  found_in_list=in_list.select{|list_name| player_name.casecmp(list_name)==0}.first
  puts found_in_list
  unless found_in_list
    puts "not found"
  end
end

#player_name='aPPLe'
#do_list_result=do_list(['Apple','Banana','apple'],player_name)

#if do_list_result
#  puts "Found #{do_list_result} list"
#else
#  puts "Not in list"
#end

votes={"Apple"=>"A", "Banana"=>"B", "Ape"=>"A"}
counts=Hash.new(0)
counts['']=0
votes.keys.each do |name|
  target_name=votes[name]
  counts[target_name]+=1 unless target_name.nil? or target_name==''
end

choices=["A","B"]
puts sorted_votes=choices.sort_by{|player_name| -counts[player_name]}
puts sorted_votes.first
