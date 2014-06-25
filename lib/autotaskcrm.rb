require 'savon'
require 'httpclient'

class AutoTaskCrm
  def initialize(username = nil, password = nil)
    @client = nil

    Savon.configure do |config|
      config.raise_errors = true
      config.soap_version = 2
      config.log = false
      config.log_level = :fatal
    end

    HTTPI.log = false

    @client = Savon::Client.new do
      wsdl.document = "https://webservices3.autotask.net/atservices/1.5/atws.wsdl"
    end

    if !username.blank? and !password.blank?
      @client.http.auth.basic username, password
    elsif !AUTOTASK_CONFIG['username'].blank? and !AUTOTASK_CONFIG['password'].blank?
      @client.http.auth.basic AUTOTASK_CONFIG['username'], AUTOTASK_CONFIG['password']
    else
      return false
    end
  end

  def send_xml(xml)
    resp = @client.request :query do
      soap.body = { :sXML => "<queryxml>#{xml}</queryxml>" } 
    end

    resp.body[:query_response][:query_result][:entity_results].is_a?(Hash) ? resp : false
  end

  def get_ticket_id(ticket_name)
      return nil unless ticket_name.match(Regexp.new(/^T[0-9]{8}\.[0-9]{4}$/))

      resp = send_xml("<entity>ticket</entity><query><field>ticketnumber<expression op='equals'>#{ticket_name.strip}</expression></field></query>") 
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity][:id] : nil
  end
  
  def get_tickets(account_id, year, month)
    query = <<-EOS
    <entity>Ticket</entity>
    <query>
      <condition>
        <field>AccountID<expression op='equals'>#{account_id}</expression></field>
      </condition>
      <condition>
        <condition> 
          <field>Status<expression op='NotEqual'>5</expression></field>
        </condition>
        <condition>
          <field>CreateDate<expression op='GreaterThanOrEquals'>#{Date.parse("#{year}-#{month}-01")}</expression></field>
        </condition>
        <condition>
          <field>CreateDate<expression op='LessThanOrEquals'>#{Date.parse("#{year}-#{month}-#{(Date.new(year, 12, 31) << (12-month)).day}")}</expression></field>
        </condition>
        <condition operator='OR'>
          <condition> 
            <field>Status<expression op='Equals'>5</expression></field>
          </condition>
          <condition>
            <field>CreateDate<expression op='GreaterThanOrEquals'>#{Date.parse("#{year}-#{month}-01")}</expression></field>
          </condition>
          <condition>
            <field>CreateDate<expression op='LessThanOrEquals'>#{Date.parse("#{year}-#{month}-#{(Date.new(year, 12, 31) << (12-month)).day}")}</expression></field>
          </condition>
          <condition>
            <field>ResolvedDateTime<expression op='GreaterThanOrEquals'>#{Date.parse("#{year}-#{month}-#{(Date.new(year, 12, 31) << (12-month)).day}")}</expression></field>
          </condition>
        </condition>
        <condition operator='OR'>
          <condition>
            <field>ResolvedDateTime<expression op='GreaterThanOrEquals'>#{Date.parse("#{year}-#{month}-01")}</expression></field> 
          </condition>
          <condition>
            <field>ResolvedDateTime<expression op='LessThanOrEquals'>#{Date.parse("#{year}-#{month}-#{(Date.new(year, 12, 31) << (12-month)).day}")}</expression></field>
          </condition>
        </condition>
      </condition>
      <condition>
        <condition>
          <field>QueueID<expression op='equals'>29730010</expression></field>
        </condition>
        <condition operator='OR'>
          <field>QueueID<expression op='equals'>29685031</expression></field>
        </condition>
        <condition operator='OR'>
          <field>QueueID<expression op='equals'>29682833</expression></field>
        </condition>
        <condition operator='OR'>
          <field>QueueID<expression op='equals'>29789587</expression></field>
        </condition>
      </condition>
    </query>
    EOS

    response = send_xml(query)
    response != false ? response.body[:query_response][:query_result][:entity_results][:entity] : nil
  end

  def get_task_id(task_name)
      return nil unless task_name.match(Regexp.new(/^T[0-9]{8}\.[0-9]{4}$/))

      resp = send_xml("<entity>task</entity><query><field>tasknumber<expression op='equals'>#{task_name.strip}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity][:id] : nil
  end

  def get_project_by_task(task_name)
      return nil unless task_name.match(Regexp.new(/^T[0-9]{8}\.[0-9]{4}$/))

      resp = send_xml("<entity>task</entity><query><field>tasknumber<expression op='equals'>#{task_name.strip}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity][:project_id] : nil
  end

  def get_account_by_project(project_id)
      resp = send_xml("<entity>project</entity><query><field>id<expression op='equals'>#{project_id.strip}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity][:account_id] : nil
  end


 def get_accounts(from_date = nil)
    Rails.cache.fetch("accounts", :expires_in => 1.days) do
      if from_date == nil
        resp = send_xml("<entity>account</entity><query><field>accountname<expression op='IsNotNull'></expression></field></query>")
      else
        resp = send_xml("<entity>account</entity><query><field>LastActivityDate<expression op='GreaterThan'>#{Date.parse(from_date)}</expression></field></query>")
      end
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity].sort_by { |k,v| k[:account_name] } : nil
    end
  end

  def get_account_name(account_id)
    Rails.cache.fetch("account_name_#{account_id}", :expires_in => 1.weeks) do
      resp = send_xml("<entity>account</entity><query><field>id<expression op='equals'>#{account_id}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity][:account_name].strip : nil
    end
  end
  
  def get_account_information(account_id)
    Rails.cache.fetch("account_information", :expires_in => 1.days) do
      resp = send_xml("<entity>account</entity><query><field>id<expression op='equals'>#{account_id}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
    end
  end

  def get_contracts(account_id)
      resp = send_xml("<entity>contract</entity><query><field>AccountID<expression op='equals'>#{account_id}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
  end
  
  def get_contract(contract_id)
      resp = send_xml("<entity>contract</entity><query><field>id<expression op='equals'>#{contract_id}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
  end

  def get_contacts(account_id)
      resp = send_xml("<entity>contact</entity><query><field>AccountID<expression op='equals'>#{account_id}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
  end

  def get_contact(contact_id)
    Rails.cache.fetch("contact_name_#{contact_id}", :expires_in => 1.weeks) do
      resp = send_xml("<entity>contact</entity><query><field>id<expression op='equals'>#{contact_id}</expression></field></query>")
      resp != false ? "#{resp.body[:query_response][:query_result][:entity_results][:entity][:first_name]} #{resp.body[:query_response][:query_result][:entity_results][:entity][:last_name]}" : nil
    end
  end

  def get_account_by_contact(contact_id)
    Rails.cache.fetch("account_by_contact_#{contact_id}", :expires_in => 4.weeks) do
      resp = send_xml("<entity>contact</entity><query><field>id<expression op='equals'>#{contact_id}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity][:account_id] : nil
    end
  end

  def get_account_by_ticket(ticket_id)
    Rails.cache.fetch("account_by_ticket_#{ticket_id}", :expires_in => 4.weeks) do
      resp = send_xml("<entity>ticket</entity><query><field>id<expression op='equals'>#{ticket_id}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity][:account_id] : nil
    end
  end

  def get_account_udf(account_id, field)
    response = send_xml("<entity>account</entity><query><field>id<expression op='equals'>#{account_id}</expression></field></query>")
    hash = response != false ? response.body[:query_response][:query_result][:entity_results][:entity][:user_defined_fields] : ""
    if hash.is_a?(Hash)
      hash[:user_defined_field].each do |udf|
        return udf[:value] if udf[:name] == field
      end
        return ""
    else
      return ""
    end
  end
  
  # Integer to String Handling for Priorities and Sources on Tickets
  def get_priority(id)
    case id.to_i
    when 4
      return 'Critical'
    when 3
      return 'Low'
    when 2
      return 'Medium'
    when 1
      return 'High'
    else
      return 'Unknown'
    end
  end

  def get_source(id)
    case id.to_i
    when -2
      return 'Insourced'
    when -1
      return 'Client Portal'
    when 1
      return 'Other'
    when 2
      return 'Call'
    when 3
      return 'Voice Mail'
    when 4
      return 'Email'
    when 6
      return 'Verbal'
    else
      return 'Unknown'
    end
  end

end
