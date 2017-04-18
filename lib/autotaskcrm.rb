require 'savon'
require 'httpclient'

class AutoTaskCrm
  def initialize(username = nil, password = nil)
    @client = nil

    #Savon.configure do |config|
    #  config.raise_errors = false
    #  config.soap_version = 2
    #  config.log = false
    #  config.log_level = :fatal
    #end

    HTTPI.log = false

    if !username.blank? and !password.blank?
      @username = username
      @password = password
    elsif !AUTOTASK_CONFIG['username'].blank? and !AUTOTASK_CONFIG['password'].blank?
      @username = AUTOTASK_CONFIG['username']
      @password = AUTOTASK_CONFIG['password']
    else
      return false
    end
    
    @client = Savon.client do
      wsdl "https://webservices3.autotask.net/atservices/1.5/atws.wsdl"
      basic_auth [@username,@password]
    end
    
  end

  def send_xml(xml, query = true)
    if query == true
      resp = @client.call(:query, xml: "<queryxml>#{xml}</queryxml>")
      resp.body[:query_response][:query_result][:entity_results].is_a?(Hash) ? resp : false
    else
      resp = @client.call(:create, xml: "<?xml version='1.0' encoding='UTF-8'?><soap:Envelope xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:xsd='http://www.w3.org/2001/XMLSchema' xmlns:soap='http://www.w3.org/2003/05/soap-envelope'><soap:Body><create xmlns='http://autotask.net/ATWS/v1_5/'>#{xml}</create></soap:Body></soap:Envelope>")
    end
  end

  def create_ticket(account_id, title, description, priority, due_date, contact_id, source)
    return nil if account_id.blank? or title.blank? or description.blank?

    resp = send_xml("<Entities><Entity xsi:type='Ticket'><AccountID>#{account_id}</AccountID><Priority>#{priority}</Priority><Status>1</Status><Title>#{title}</Title><Description xsi:type='xsd:string'><![CDATA[#{description}]]></Description><UserDefinedFields /><DueDateTime>#{DateTime.parse(due_date).strftime("%Y-%m-%d %H:%M:%S")}</DueDateTime><ContactID>#{contact_id}</ContactID><QueueID>29730010</QueueID><WorkType>29730009</WorkType><Source>#{source}</Source></Entity></Entities>", query = false)
    resp != false ? resp.body : nil
  end

  def create_ticket_note(ticket_id, title, description)
    return nil if ticket_id.blank? or title.blank? or description.blank?

    resp = send_xml("<Entities><Entity xsi:type='TicketNote'><TicketID>#{ticket_id}</TicketID><Title>#{title}</Title><Description>#{description}</Description><NoteType>18</NoteType><Publish>1</Publish></Entity></Entities>", query = false)
    resp != false ? resp.body : nil
  end

  def get_ticket_id(ticket_name)
      return nil unless ticket_name.match(Regexp.new(/^T[0-9]{8}\.[0-9]{4}$/))

      resp = send_xml("<entity>ticket</entity><query><field>ticketnumber<expression op='equals'>#{ticket_name.strip}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity][:id] : nil
  end

  def get_ticket(ticket_name)
    return nil unless ticket_name.match(Regexp.new(/^T[0-9]{8}\.[0-9]{4}$/))
    
    resp = send_xml("<entity>ticket</entity><query><field>ticketnumber<expression op='equals'>#{ticket_name.strip}</expression></field></query>")
    resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
  end

  def get_ticket_by_id(ticket_id)
    return nil if ticket_id.blank?

    resp = send_xml("<entity>ticket</entity><query><field>id<expression op='equals'>#{ticket_id.strip}</expression></field></query>")
    resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
  end
  
  def get_ticket_notes(ticket_id)
    resp = send_xml("<entity>ticketnote</entity><query><condition><field>ticketid<expression op='equals'>#{ticket_id}</expression></field></condition><condition><field>Publish<expression op='equals'>1</expression></field></condition><condition><field>notetype<expression op='notequal'>13</expression></field></condition></query>")
    resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
  end

  def get_ticket_note(ticket_note_id)
    resp = send_xml("<entity>ticketnote</entity><query><condition><field>id<expression op='equals'>#{ticket_note_id}</expression></field></condition></query>")
    resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : ni
  end
  
  def get_ticket_time_entries(ticket_id)
    resp = send_xml("<entity>timeentry</entity><query><condition><field>ticketid<expression op='equals'>#{ticket_id}</expression></field></condition><condition><field>type<expression op='equals'>2</expression></field></condition></query>")
    resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
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
  
  def get_all_nonrecurring_tickets(account_id)
    query = <<-EOS
    <entity>Ticket</entity>
    <query>
      <condition>
        <field>AccountID<expression op='equals'>#{account_id}</expression></field>
      </condition>
      <condition>
        <field>CreateDate<expression op='GreaterThanOrEquals'>#{Date.today - 6.months}</expression></field>
      </condition>
      <condition>
        <condition>
          <field>QueueID<expression op='NotEqual'>29746061</expression></field>
        </condition>
        <condition operator='AND'>
          <field>QueueID<expression op='NotEqual'>29746065</expression></field>
        </condition>
        <condition operator='AND'>
          <field>QueueID<expression op='NotEqual'>29747641</expression></field>
        </condition>
      </condition>
    </query>
    EOS

    response = send_xml(query)
    response != false ? response.body[:query_response][:query_result][:entity_results][:entity] : nil
  end
  
  def get_all_open_tickets(account_id)
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
      </condition>
      <condition>
        <condition>
          <field>QueueID<expression op='NotEqual'>29746061</expression></field>
        </condition>
        <condition operator='AND'>
          <field>QueueID<expression op='NotEqual'>29746065</expression></field>
        </condition>
        <condition operator='AND'>
          <field>QueueID<expression op='NotEqual'>29747641</expression></field>
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
    resp = send_xml("<entity>account</entity><query><field>id<expression op='equals'>#{account_id}</expression></field></query>")
    resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
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
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
    end
  end
  
  def get_resource(resource_id)
    Rails.cache.fetch("resource_name_#{resource_id}", :expires_in => 1.weeks) do
      resp = send_xml("<entity>resource</entity><query><field>id<expression op='equals'>#{resource_id}</expression></field></query>")
      resp != false ? resp.body[:query_response][:query_result][:entity_results][:entity] : nil
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
