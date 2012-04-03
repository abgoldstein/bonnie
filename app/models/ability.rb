class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new

    if user.admin?
      can :manage, :all
    elsif user.id
      can :read, :dashboard
      can :manage, Measure
    end

  end
end
