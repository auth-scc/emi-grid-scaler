require 'rubygems'
require 'net/ssh'

class CreamHandler  
  @@etc_hosts_file_path = '/etc/hosts'
  
  @@wn_list_conf_path = '/opt/glite/yaim/etc/siteinfo/wn-list.conf'
    
  def self.queue_stats
    stats = {}
    showq_cmd = ""
    
    if ScalerConfig.cream_local
      showq_cmd = %x[showq]
    else
      Net::SSH.start( 'cream.afroditi.hellasgrid.gr', 'ansible' ) do |session|
        showq_cmd = session.exec!('showq')
      end
    end

    stats[:total_jobs], stats[:active_jobs], stats[:idle_jobs], stats[:blocked_jobs] = showq_cmd.match(/^Total Jobs: (\d+)   Active Jobs: (\d+)   Idle Jobs: (\d+)   Blocked Jobs: (\d+)$/).captures.collect {|d| d.to_i}

    stats[:working_processors], stats[:total_processors] = showq_cmd.match(/(\d+) of   (\d+) Processors Active/).captures.collect {|d| d.to_i}

    stats[:working_nodes], stats[:total_nodes] = showq_cmd.match(/(\d+) of   (\d+) Nodes Active/).captures.collect {|d| d.to_i}
    
    if ScalerConfig.debug
      p "======================================================"
      p "======================================================"
      p "               Information from cream.                "
      p "======================================================"
      p "working_nodes, total_nodes"
      print "#{stats[:working_nodes]}, \t #{stats[:total_nodes]}\n"
      p "==="
      p "working_processors, total_processors"
      print "#{stats[:working_processors]}, \t #{stats[:total_processors]}\n"
      p "==="
      p "total_jobs, active_jobs, idle_jobs, blocked_jobs"
      print "#{stats[:total_jobs]}, \t #{stats[:active_jobs]}, \t #{stats[:idle_jobs]}, \t #{stats[:blocked_jobs]}\n"
      p "======================================================"
      p "======================================================"
      p "======================================================"
    end
    
    stats
  end
  
  def self.write_to_hosts(list)

    etc_hosts_file = File.open(@@etc_hosts_file_path, 'a')

    list.each do |ip_name_fqdn|
      etc_hosts_file.write "#{ip_name_fqdn.join(' ')}\n"
    end
        
    etc_hosts_file.close
    
    if ScalerConfig.debug
      p "Printing /etc/hosts new file"
      p File.readlines(@@etc_hosts_file_path)
    end
  end
  
  def self.delete_from_hosts(ip_list)
        
    etc_hosts_lines = File.readlines(@@etc_hosts_file_path)
    
    etc_hosts_lines.reject! {|line| ip_list.include? line.split.first }
    
    check_file_lines(etc_hosts_lines)
    
    File.open(@@etc_hosts_file_path, 'w') {|f| f.write etc_hosts_lines}
    
    if ScalerConfig.debug
      p "Printing /etc/hosts new file"
      p File.readlines(@@etc_hosts_file_path)
    end
  end
  
  def self.add_wns_to_wn_list(fqdn_list)
    
    # wn_list_conf_file = File.open(@@wn_list_conf_path, 'a')
    wn_list_conf_lines = File.readlines(@@wn_list_conf_path)

    fqdn_list.each do |fqdn|
      wn_list_conf_lines << "#{fqdn}\n"
    end
    
    # Check if all lines have a \n at the end.
    check_file_lines(wn_list_conf_lines)
    
    # Add one empty line at the end.
    # wn_list_conf_file.write "\n"
    
    # Write file.
    # wn_list_conf_file.close
    File.open(@@wn_list_conf_path, 'w') {|f| f.write wn_list_conf_lines}
    
    if ScalerConfig.debug
      p "Printing wn-list.conf new file" 
      p File.readlines(@@wn_list_conf_path)
    end
  end
  
  def self.delete_wns_from_wn_list(fqdn_list)
    wn_list_conf_lines = File.readlines(@@wn_list_conf_path)
    
    wn_list_conf_lines.reject! {|line| fqdn_list.include? line.strip! }
    
    # Check if all lines have a \n at the end.
    check_file_lines(wn_list_conf_lines)
    
    File.open(@@wn_list_conf_path, 'w') {|f| f.write wn_list_conf_lines.join("\n") }
    
    # Add one empty line at the end.
    # File.open(@@wn_list_conf_path, 'a') {|f| f.write "\n" }
    
    if ScalerConfig.debug
      p "Printing wn-list.conf new file" 
      p File.readlines(@@wn_list_conf_path)
    end
  end
  
  def self.restart_yaim!
    p "Restarting YAIM!" if ScalerConfig.debug
    
    if ScalerConfig.cream_local
      #yaim_cmd = '/opt/glite/yaim/bin/yaim -c -s /opt/glite/yaim/etc/siteinfo/site-info.def -n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site'
      yaim_cmd = '/opt/glite/yaim/bin/yaim -r -s /opt/glite/yaim/etc/siteinfo/site-info.def -n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site -f config_torque_server -f config_maui_cfg -f config_torque_submitter_ssh'
      IO.popen(yaim_cmd, mode='r') do |cmd_stream| 
        until cmd_stream.eof?
          puts cmd_stream.gets
        end
      end
    else
      Net::SSH.start( 'cream.afroditi.hellasgrid.gr', 'ansible' ) do |session|
        #session.exec!('sudo -i /opt/glite/yaim/bin/yaim -c -s /opt/glite/yaim/etc/siteinfo/site-info.def -n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site') do |ch, stream, line|
        session.exec!('/opt/glite/yaim/bin/yaim -r -s /opt/glite/yaim/etc/siteinfo/site-info.def -n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site -f config_torque_server -f config_maui_cfg -f config_torque_submitter_ssh') do |ch, stream, line|          puts line if ScalerConfig.debug
        end
      end      
    end
    
    $?.exitstatus
  end  
  
  ################## Private members ################## 
  private
  
  def self.check_file_lines(file_lines)
    file_lines.map! {|l| unless l =~ /.*\n$/ then l += "\n" else l end }
  end
end