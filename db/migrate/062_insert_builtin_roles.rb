class InsertBuiltinRoles < ActiveRecord::Migration
  def self.up
    # rails doesn't know about the previously created builtin attribute without this
    Role.reset_column_information

    nonmember = Role.new(:name => 'Non member', :position => 0)
    nonmember.assign_attributes({ :builtin => Role::BUILTIN_NON_MEMBER }, :without_protection => true )
    nonmember.save
    
    anonymous = Role.new(:name => 'Anonymous', :position => 0)
    anonymous.assign_attributes({ :builtin => Role::BUILTIN_ANONYMOUS }, :without_protection => true )
    anonymous.save
  end

  def self.down
    Role.destroy_all 'builtin <> 0'
  end
end
