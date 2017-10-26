json.teams do
  json.array teams do |team|
    json.id team.id
    json.name team.name
    json.members team.members
    json.role retrive_role_name(team.role)
    json.can_be_leaved team.can_be_leaved
    json.user_team_id team.user_team_id
  end
end
