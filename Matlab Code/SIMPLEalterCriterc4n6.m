function [z, v, x] = SIMPLE(figures, p_error, ChurnDepth, NumberOfNodes, Nesterov,alphaParameter, Threshold)
%% Sync/Desync Protocol Implementation
%
% Copyright © 2013 
%	George Smart, Rosario Surace, Yiannis Andreopoulos.
% 	Telecommunications Research Group.
% 	Department of Electronic & Electrical Engineering.
% 	University College London, Malet Place, London. WC1E 7JE. UK.
%
% Options
%   figures:     0=do not plot, 1=plot
%   p_error:     error probablitly in percent, i.e. for 50% loss, use 50, not 0.5.
%   ChurnDepth:  0(none), 1(low), 2(medium) or 3(high).
%                Loads a stable file (saved from previous run at
%                convergence) and then churns nodes. See code.
%
% Revisions
% 	25 February, 2013		Rosario Surace			Initial
% 	25 February, 2013		George Smart			Initial
% 	25 July, 2013			George Smart			Added debug text
% 	12 Sept, 2013			George Smart			Added 16 channels
% 	27 Sept, 2013			George Smart			Complete rewrite using cell arrays.
%  	9 Oct, 2013          	George Smart            Added code for N_E and N_C
%   11 Oct, 2013          	George Smart            Code for dynamic N_E
%   12 Oct, 2013          	George Smart            Swapped Balancing code to use DESYNC node
%   4 July 2014             George Smart            Simplified Version for New Paper

% make sure that NC is taken in to accoutn when desync nodes leave.  

function a = status(t,m)
% STATUS takes status('title text', 'message text') as two strings, such all output follows a similar style.
	display([num2str(uloop) '(' num2str(minIterations) '):   *** ' t ' --- ' m ' ***'])
end

function a = recount_nodes()
% recount_nodes updates the n{j} vector based on the lengths of currPhase{j}
	for j = 1:maxC
		n(j) = length(currPhase{j});
	end
end

function a = remap_connectivity()
% remap_connectivity recreates the conectivity[j] matrix based on the n{mapvar} vector.
	for mapvar = 1:maxC
		connectivity{mapvar} = ones(n(mapvar),n(mapvar))-diag(ones(1,n(mapvar)));
	end
end

function a = remove_node(c)
        
        NodeLeaving = n(c) - (n(c) == vertical_node(1,c));
        
        % delete parameters of the old sink
        currPhase{c}(NodeLeaving) = [];
        testPhase{c}(NodeLeaving) = []; % if vertical_node(1,1) has more than one true
        firing{c}(NodeLeaving) = [];   % element, we'll loose the difference
        fired{c}(NodeLeaving) = [];    % in nodes, as we only add one below
        fired_2{c}(NodeLeaving) = [];   % but remove all true instances. GS.
        justFired{c}(NodeLeaving) = [];
        tot_sending{c}(NodeLeaving) = [];
        
        if (NodeLeaving<vertical_node(1,c))
        	vertical_node(1,c) = vertical_node(1,c) - 1;
        end
        
        
        % recount nodes on each channel
        recount_nodes();
        
        % map connectivity matrix
        remap_connectivity();
        
        % udate the index of problems
        ind_prob{c} = ind_prob{c} + 1;
end

function a = add_node(c)
        % Printing initial values
        % insert parameters of the new node
        currPhase{c} = [currPhase{c} rand(1)]; % assign random phase
        testPhase{c} = [testPhase{c} 0];
        firing{c} = [firing{c} 0];
        fired{c} = [fired{c} 1];
        fired_2{c} = [fired_2{c} 0];
        justFired{c} = [justFired{c} 0];
        tot_sending{c} = [tot_sending{c} 0];
        fired_old{c} = [fired_old{c} 0];
        
        % go in the election state
        %vertical_node(1,c)=(-1*electionLoss(c));
        
        % recount nodes on each channel
        recount_nodes();
        
        % map connectivity matrix
        remap_connectivity();
        
        % udate the index of problems
        ind_prob_entry{c} = ind_prob_entry{c} + 1;
end

function a = check_channel_node_left(c)
% check_channel_node_left checks sync_leaves_channel{c} to see if a node is due to leave channel {c} for iteration iterations{c} and acts accordingly.
    if(ind_prob{c}<=np{c} && node_leaves_channel{c}(1,ind_prob{c})==iterations{c} && node_leaves_channel{c}(1,ind_prob{c})>0)
        remove_node(c);
    end
end

function a = check_channel_node_join(c)
% check_channel_node_join checks new_node_enters_channel{c} to see if a node is due to join channel {c} for iteration iterations{c} and acts accordingly.
	if(ind_prob_entry{c}<=np_entry{c} && new_node_enters_channel{c}(1,ind_prob_entry{c})==iterations{c} && new_node_enters_channel{c}(1,ind_prob_entry{c})>0)
        add_node(c)
    end
end

function a = channel_computation(c)
% channel_computation Compute the sync/desync for each channel

	% next node to fire
	maxPhase = max(currPhase{c});
	indice = (currPhase{c} == maxPhase);
	
	% save the precedent fire
    % for some reason, equating cells does everyting, so we go to a single
    % vector called temp.
    
	fired_old{c} = fired{c};
    fired{c} = fired_2{c};
    firing{c} = indice;
    fired_2{c} = firing{c}; 
    
    d = c + 1;
    if (d > maxC)
        d = 1;
    end
    
    b = c - 1;
	if (b < 1)
		b = maxC;
    end
	
	% compute and update the new phase
	dP = 1 - maxPhase;
	currPhase{c} = currPhase{c} + dP;
	
	% save the time of the fire
	simtime_prev{c} = simtime_jumping{c};
	simtime_jumping{c} = simulationTime{c};
	simulationTime{c} = simulationTime{c} + dP;
	simtime_fire{c} = simulationTime{c};
	
	if(find(firing{c} == 1, 1)==vertical_node(1,c))
		simtime_sinkfire_storage{c}(vertical_node(1,c),count_firing_sink{c}) = simtime_fire{c};
		count_firing_sink{c} = count_firing_sink{c} + 1;
	end
	
	if(find(firing{c} == 1, 1)==vertical_node(1,c))
		simtime_fire_storage{c}(1,count_firing_storage{c}) = simtime_fire{c};
		count_firing_storage{c} = count_firing_storage{c} + 1;
	end
	
	% simulate the "fire"
	currPhase{c}(firing{c}) = 0;
	justFired{c} = firing{c} | justFired{c};
    sending = firing{c}; % & (rand(1,n(c)) <= p_sendingloss(c)); % packet loss handled differently here.
	neighbours = any(connectivity{c}(sending,:),1);
	jumping{c} = neighbours & justFired{c};
    
    %status(['Sync/Desync Choice in Channel ' num2str(c)], ['Work: ' num2str(node_to_work_on) ', Sync: ' num2str(channel_sync_node)])
    
    testPhase{c} = currPhase{c};

	% Desync code
	if(find(jumping{c} == 1, 1) ~= vertical_node(1,c))
		% add messagge missing error
		random_number=rand(1,1);
		if(random_number<=p_packetloss(c))
			%status(['No Desync in Channel ' num2str(c)],'Message lost!')
			desync_lost_frames(c) = desync_lost_frames(c) + 1;
		else
			if (sum(fired_old{c}) > 0) % if node has switched, it will not have a clue who fired last, so the vector will have no true element, and thus should fire at it's old time (i.e. don't run)
				%status(['Desync in Channel ' num2str(c)],'OK')
				%compute the next and prev currPhade (add timing error if enable)
				cpf{c} = currPhase{c}(find(firing{c} == 1, 1)) + (enable_timing_errors * (min_value_timing_error + (rand(1,1) * (max_value_timing_error - min_value_timing_error))));
				cpfo{c} = currPhase{c}(find(fired_old{c} == 1, 1)) + (enable_timing_errors * (min_value_timing_error + (rand(1,1) * (max_value_timing_error - min_value_timing_error))));
				
				% compute the jump ONLY IF the node is not a ghost
               if (desync_node_left(c) < 0)
                   if(NESTEROV)
                       aux_nesterov{c}(jumping{c}) = nesterov_Phase{c}(jumping{c});
                       nesterov_Phase{c}(jumping{c}) = (((1-coupling) * currPhase{c}(jumping{c})) + (coupling*((cpf{c}+cpfo{c})/2)));
                       currPhase{c}(jumping{c}) = nesterov_Phase{c}(jumping{c})+((iterations{c})/(iterations{c}+3)) *(nesterov_Phase{c}(jumping{c})-aux_nesterov{c}(jumping{c}));
                   else
                       currPhase{c}(jumping{c}) = (((1-coupling) * currPhase{c}(jumping{c})) + (coupling*((cpf{c}+cpfo{c})/2)));
                   end
                   numberOfUpdates{j}(jumping{c}) = numberOfUpdates{j}(jumping{c}) +1; 
               end
                % if the desync update is outside the threshold, then we're
                % not converged.
                    if ((abs(currPhase{c}(jumping{c}) - testPhase{c}(jumping{c})) > 0.5))%&&(iterations{c}>5)
                        %display('NESTEROV switched off')           
                        NESTEROV=0;
                    end
                if ((abs(currPhase{c}(jumping{c}) - testPhase{c}(jumping{c})) <= desyncThreshold))
                    desync_lost_frames(c) = 0;
                else
                    desync_lost_frames(c) = desync_lost_frames(c) + 1;
                end
			end
		end
    end


                
	% Sync code
    if(find(firing{c} == 1, 1) == vertical_node(1,c))
        [~,nc]=size(simtime_fire_storage{c});
        [~,nb]=size(simtime_fire_storage{b});
        
        aux_sync_counter = aux_sync_counter+1;
        sync_counter = floor((aux_sync_counter-1)/maxC);
        
        % add missing message error
        random_number=rand(1,1);
        if(random_number<=p_packetloss(c))
            %status(['No Sync in Channel ' num2str(c)],'Message lost!')
            sync_lost_frames(b) = sync_lost_frames(b) + 1;
        else
            %status(['Sync in Channel ' num2str(c)],'OK')
            % compute the phase of next sync node (add timing error if enable)
            sfs = simtime_fire_storage{c}(1,nc) + (enable_timing_errors * (min_value_timing_error + (rand(1,1) * (max_value_timing_error - min_value_timing_error))));
            phi = abs(sfs - simtime_fire_storage{b}(1,nb)) - floor(abs(sfs - simtime_fire_storage{b}(1,nb)));
            if (phi <= 0.001 || (sfs <= simtime_fire_storage{b}(1,nb)))
                % do nothing
            else
                if(CONVENTIONAL_SYNC)
                    % compute the new phase
                    if(beta * phi > 1)
                        new_phase_of_sync = 1;
                    else
                        new_phase_of_sync = beta * phi;
                    end
                    if( vertical_node(1,b)>0)  %phi > (1/maxC) &&must be changed for correct listening interval for number of SYNC nodes.
                        %update the phase with the new phase (add compensation for the time)
                        currPhase{b}(1,vertical_node(1,b))=(new_phase_of_sync)-phi+currPhase{b}(1,vertical_node(1,b));
                        currPhase{b}(currPhase{b} < 0) = 0;
                        currPhase{b}(currPhase{b} > 1) = 1;
                        
                        if (abs(currPhase{b}(1,vertical_node(1,b)) - testPhase{b}(1,vertical_node(1,b))) <= syncThreshold)
                            sync_lost_frames(b) = 0;
                        else
                            sync_lost_frames(b) = sync_lost_frames(b) + 1;
                        end
                    end
 %------------------------------------------------------------------------------------------------------------    
                end
%                 if(TEST)
%                     if((phi+gamma*(1-phi)) > 1)
%                         new_phase_of_sync = 1;
%                     else
%                         new_phase_of_sync = phi+gamma*(1-phi);
%                         %new_phase_of_sync = 1;
%                     end                   
%                     if(phi > (1/maxC) && vertical_node(1,b)>0)  % must be changed for correct listening interval for number of SYNC nodes.
%                         %update the phase with the new phase (add compensation for the time)
%                         currPhase{b}(1,vertical_node(1,b))=(new_phase_of_sync)-phi+currPhase{b}(1,vertical_node(1,b));
%                         currPhase{b}(currPhase{b} < 0) = 0;
%                         currPhase{b}(currPhase{b} > 1) = 1;
%                         
%                         if (abs(currPhase{b}(1,vertical_node(1,b)) - testPhase{b}(1,vertical_node(1,b))) <= syncThreshold)
%                             sync_lost_frames(b) = 0;
%                         else
%                             sync_lost_frames(b) = sync_lost_frames(b) + 1;
%                         end
%                     end
%                 end
%                 if(NESTEROV && ~CONVENTIONAL_SYNC && ~TEST)
% %                     if((phi+gamma*(1-phi)) > 1)
% %                         new_phase_of_sync = 1;
% %                     else
% %                         new_phase_of_sync = phi+gamma*(1-phi);
% %                     end 
%                     % compute the new phase
%                     %display(['nc= ', num2str(nc)])
%                     if(beta * phi > 1)
%                         new_phase_of_sync = 1;
%                     else
%                         new_phase_of_sync = beta * phi;
%                     end
%                     if (nesterov_first_time_counter(1,b)==0)
%                        nesterov_Phase{b}(1,vertical_node(1,b)) = phi;
%                     end
%                     if(phi > (1/maxC) && vertical_node(1,b)>0)  % must be changed for correct listening interval for number of SYNC nodes.
%                         %update the phase with the new phase (add compensation for the time)
%                         aux_nesterov{b}(1,vertical_node(1,b)) = nesterov_Phase{b}(1,vertical_node(1,b));
%                         nesterov_Phase{b}(1,vertical_node(1,b))=(new_phase_of_sync)-phi+currPhase{b}(1,vertical_node(1,b));
%                         if(new_phase_of_sync == phi)
%                             currPhase{b}(1,vertical_node(1,b))=(new_phase_of_sync)-phi+currPhase{b}(1,vertical_node(1,b));
%                          else
%                             currPhase{b}(1,vertical_node(1,b)) = nesterov_Phase{b}(1,vertical_node(1,b))+((sync_counter)/(sync_counter+3))*(nesterov_Phase{b}(1,vertical_node(1,b))-aux_nesterov{b}(1,vertical_node(1,b)));
%                         end
%                         currPhase{b}(currPhase{b} < 0) = 0;
%                         currPhase{b}(currPhase{b} > 1) = 1;
%                         
%                         if (abs(currPhase{b}(1,vertical_node(1,b)) - testPhase{b}(1,vertical_node(1,b))) <= syncThreshold)
%                             sync_lost_frames(b) = 0;
%                         else
%                             sync_lost_frames(b) = sync_lost_frames(b) + 1;
%                         end
%                         %counts the number of times the sync node has undergone
%                         %updates -- it is used to initiate the
%                         %nesterov_sync_Phase with phi
%                          
%                     end
%                     nesterov_first_time_counter(1,b) = nesterov_first_time_counter(1,b)+1;
%                 end
 %------------------------------------------------------------------------------------------------------------ 
            end
        end
    end
end

function a = check_channel(c)
	% update variable
	tot_sending{c} = tot_sending{c} | jumping{c};
	currPhase{c}(currPhase{c} < 0) = 0;
	currPhase{c}(currPhase{c} > 1) = 1;
	justFired{c} = ~jumping{c} & justFired{c};
	max_phase_error{c} = max(abs(currPhase{c} - testPhase{c}));
    %max_phase_error{c} = sum((currPhase{c} - testPhase{c}).^2);
    %display(['Sum of Squared Errors --> ',num2str(max_phase_error{c})])
	u{c} = u{c} + 1;
	
	% save the fire for the plot
	st{c}(u{c}) = simulationTime{c};
    
    
    if (iterationsOld{c} ~= iterations{c})
        %status(['New iteration on channel ' num2str(c)],['Iteration ' num2str(iterations{c})])
        convergedIterations{c} = convergedIterations{c} + 1;
        
        % if we've lost NE frames, then cause re-election by removing sync.
        if (  ((sync_lost_frames(c)) >= electionLoss(c))  )
            sync_lost_frames(c) = 0;
            if (convergedIterations{c} > convergenceIterations)
                status(['Kicked Sync in Channel ' num2str(c)],'')
                %vertical_node(1,c)=(-1*electionLoss(c));
                vertical_node(1,c)=0;
            end
        end
        
%         % if we're out of threshold, or we;ve lost NC frames, un-converge.
%         if ( (max_phase_error{c} > desyncThreshold) || (desync_lost_frames(c) >= convergenceLoss)  )
%             convergedIterations{c} = 0;
%             desync_lost_frames(c) = 0;
%             itsConverged{c} = 0;
%         end
        
            
        % if we're out of threshold, or we;ve lost NC frames, un-converge.
        %objective function value
        sortedPhase = sort(currPhase{c});
        objFunction = 0.5*(norm(D*(sortedPhase')-uVec+eVec))^2;
        %objFunction = 0.5*(norm(D*(sortedPhase')-uVec))^2;
        if ( (objFunction > desyncThreshold) || (desync_lost_frames(c) >= convergenceLoss) )
            convergedIterations{c} = 0;
            desync_lost_frames(c) = 0;
            itsConverged{c} = 0;
        end
        
    end
    
	% check for new iteration
	if (all(tot_sending{c}))
		tot_sending{c}=zeros(1,n(c));
		iterationsOld{c} = iterations{c};
		iterations{c} = iterations{c} + 1;
    end
    
	if ( (convergedIterations{c} >= convergenceIterations) && (itsConverged{c} == 0) )
		itsConverged{c} = iterations{c};
		s1{c}=simulationTime{c};	
		status(['Channel ' num2str(c) ' Converged'],['Iteration ' num2str(itsConverged{c})])
    end
end

function a = check_data_possible(c)
    if(iterations{c} > 0)
        sent_data_packets{c}(iterations{c}) = (convergedIterations{c} > 0);
    end
end

function a = calculate_NE(c)
%   (Thu 10 Oct 2013)
%   (23:36:42) Yiannis Andreopoulos: and you increase N_E by 0.5*<number of elections in last 10 periods>
%   (23:37:03) Yiannis Andreopoulos: if <number of elections in last 10 periods> == 0, then you decrease it by 1
%   (23:37:09) Yiannis Andreopoulos: up to N_e == 3
    if ((iterations{c} - sync_elections_update(c)) >= 10)
        if (sync_elections(c) > 0)
            electionLoss(c) = electionLoss(c) + round(0.5 * sync_elections(c));
             if (electionLoss(c) > electionLossMax)
                 electionLoss(c) = electionLossMax;
             end
        else
            electionLoss(c) = electionLoss(c) - 1;
            if (electionLoss(c) < electionLossMin)
                electionLoss(c) = electionLossMin;
            end
        end
        sync_elections(c) = 0;
        sync_elections_update(c) = iterations{c};
        %status(['electionLoss(' num2str(c) ')'], num2str(electionLoss(c)))
    end
end


%% Parameters
close all;
% Number of channels to simulate (may not work correctly)
maxC = 6;

% Number of nodes per channel
if (maxC == 1)
    n(1) = NumberOfNodes;
else
    n = [5, 5, 5, 5, 5, 5];
    %n = [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4];
    %n = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
end

% Hard code the sync node to be the first node.
vertical_node(1:maxC) = 1;  % hard code node 1 to be sync node
vertical_its(1:maxC) = 0;

ninit = n;

NESTEROV = Nesterov;
TEST = 0;
CONVENTIONAL_SYNC=1;
gamma = 1.3;

% --------------------------------------------
% Nesterov Sync Parameters
nesterov_sync_Phase = zeros(1,maxC);
nesterov_sync_Phase_aux = zeros(1,maxC);
nesterov_first_time_counter = zeros(1,maxC);
aux_sync_counter=0;
% --------------------------------------------

% Desync parameters
%coupling = 0.5;
coupling = alphaParameter;
convergenceLoss = 5; % NC
%desyncThreshold = 0.0001;
desyncThreshold = Threshold;
convergenceIterations = 10;

% Sync parameters
eps=0.3;
electionLoss(1:maxC) = 7; % NE
electionLossMin = 10;
electionLossMax = 20;
syncThreshold = desyncThreshold;
beta=exp(eps);
%beta = 1.1; 

% Maximum simulation time
umax=200000;
itsmax = 600; % x 100ms periods = 1 minute

% Objective function parameters
v = zeros(1,NumberOfNodes);
v(1,1)=-1; v(1,2)=1;
eVec = zeros(NumberOfNodes,1);
eVec(NumberOfNodes,1)=1;
uVec = zeros(NumberOfNodes,1)+1/NumberOfNodes;
D = gallery('circul',v);

%%%%% NON IDEAL EFFECTS %%%%%
% Messages Missing

p_loss = p_error/100;     % desync probability of failure

% Timing Errors
enable_timing_errors=0; % 0=OFF 1=ON
max_value_timing_error=0.00001;
min_value_timing_error=-0.00001;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

p_packetloss  =  p_loss * ones(1,maxC);
%p_packetloss(randi([1 maxC])) = (30/100); % targeted interference

% these get added to when a sync or desync beacon is lost.
sync_lost_frames = zeros(1,maxC);
desync_lost_frames = zeros(1,maxC);
sync_elections = zeros(1,maxC);
sync_elections_update = zeros(1,maxC);


% Data transmission
% number of data packets that are between each beacon interval.
packets_per_beacon = 1;


%%%%%%%%%% DYNAMIC CHANGES OF THE NETWORK %%%%%%%%%%

% Sync leaves -  iterations when leaves channel {n}
node_leaves_channel{1}=[0];
node_leaves_channel{2}=[0];
node_leaves_channel{3}=[0];
node_leaves_channel{4}=[0];
node_leaves_channel{5}=[0];
node_leaves_channel{6}=[0];
node_leaves_channel{7}=[0];
node_leaves_channel{8}=[0];
node_leaves_channel{9}=[0];
node_leaves_channel{10}=[0];
node_leaves_channel{11}=[0];
node_leaves_channel{12}=[0];
node_leaves_channel{13}=[0];
node_leaves_channel{14}=[0];
node_leaves_channel{15}=[0];
node_leaves_channel{16}=[0];

% A new node enters - iterations when new node enters in channel {n}
new_node_enters_channel{1}=[0];
new_node_enters_channel{2}=[0];
new_node_enters_channel{3}=[0];
new_node_enters_channel{4}=[0];
new_node_enters_channel{5}=[0];
new_node_enters_channel{6}=[0];
new_node_enters_channel{7}=[0];
new_node_enters_channel{8}=[0];
new_node_enters_channel{9}=[0];
new_node_enters_channel{10}=[0];
new_node_enters_channel{11}=[0];
new_node_enters_channel{12}=[0];
new_node_enters_channel{13}=[0];
new_node_enters_channel{14}=[0];
new_node_enters_channel{15}=[0];
new_node_enters_channel{16}=[0];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Other variables initialization
simulation_control=0;
simulation_stable=0;
minIterations=0;
maxIterations = [];
convIterations = -1;
uloop=1;
desync_node_left = -1 * ones(1,maxC);

% Variables initialization for dynamic changes of the network
for j = 1:maxC
    sent_data_packets{j} = 0;
    zmin{j} = 0;
	gs{j} = [];
	st{j} = 0;
	cv{j} = 0;
	u{j} = 0;
	itsConverged{j} = 0;
	s{j} = 0;
    connectivity{j}=[];
	ind_prob{j} = 1;
	ind_prob_entry{j} = 1;
	[mp{j},np{j}] = size(node_leaves_channel{j});
	[mp_entry{j},np_entry{j}] = size(new_node_enters_channel{j});
	simulationTime{j} = 0;
	iterations{j} = 0;
    iterationsOld{j} = 0;
	convergedIterations{j} = 0;
	max_phase_error{j} = 1;
	maxPhase{j} = 1;
	
	testPhase{j} = zeros(1,n(j));
	currPhase{j} = rand(1,n(j));
    initialPhase{j} = currPhase{j}; 
    % ------------------------------------------- NESTEROV -------------------------------------------
    nesterov_Phase{j}=currPhase{j};
	aux_nesterov{j}=currPhase{j};
    numberOfUpdates{j}=zeros(1,n(j));
    % ------------------------------------------- NESTEROV -------------------------------------------
    justFired{j} = zeros(1,n(j));
	tot_sending{j} = zeros(1,n(j));
    jumping{j}=[];
	
	firing{j} = zeros(1,n(j));
	fired{j} = zeros(1,n(j));
	fired_2{j} = zeros(1,n(j));
	fired_old{j} = zeros(1,n(j));
	
	simtime_prev{j} = 0;
	simtime_fire{j} = 0;
	simtime_jumping{j} = 0;
	simtime_fire_storage{j} = 0;
	count_firing_storage{j} = 1;
	
	count_firing_sink{j} = 1;
	simtime_sinkfire_storage{j} = 0;
end

%% Churn
if (ChurnDepth>0)
    % The following few lines will allow you to load the simulation from a
    % converged state, churn the currPhase array, and then start the simulation
    % to look at how churn effects convergence.
    
    % load a saved simulation
    status('Loading Simulation Settings','Churn');
    load ('Subroutines_Churn.mat', 'n')
    load ('Subroutines_Churn.mat', 'itsConverged')
    load ('Subroutines_Churn.mat', 'connectivity')
    load ('Subroutines_Churn.mat', 'convergedIterations')
    load ('Subroutines_Churn.mat', 'testPhase')
    load ('Subroutines_Churn.mat', 'currPhase')
    load ('Subroutines_Churn.mat', 'vertical_node')
    % load ('Subroutines_Churn.mat', '')
    
    switch ChurnDepth
        case 1
            ChurnDepthCount = (randi([2,3]));
            status('Starting state','Light Churn');
        case 2
            ChurnDepthCount = (randi([0,16]));
            status('Starting state','Medium Churn');
        case 3
            ChurnDepthCount = (randi([0,32]));
            status('Starting state','High Churn');
        otherwise
            error('ChurnDepth must be 1(low), 2(medium) or 3(high)')
    end

    status('Churn Density', [num2str(ChurnDepthCount) ' nodes']);
    
    for j = 1:maxC
        justFired{j} = zeros(1,n(j));
        tot_sending{j} = zeros(1,n(j));
        jumping{j}=[];
        
        firing{j} = zeros(1,n(j));
        fired{j} = zeros(1,n(j));
        fired_2{j} = zeros(1,n(j));
        fired_old{j} = zeros(1,n(j));
        
        convergedIterations{j} = 0;
        itsConverged{j} = 0;
    end
    
    for j = 1:ChurnDepthCount
        chan=randi(maxC);
        node=randi(n(chan));
        currPhase{chan}(node) = rand(); 
        testPhase{chan}(node) = 0;
        recount_nodes();
        remap_connectivity();
    end
else
    status('Starting state','Random')
end

%%

% Printing initial values
status('Initial Params',['n=' num2str(n)])

% recount nodes on each channel
recount_nodes();

% map connectivity matrix
remap_connectivity();

% Main Loop
while (simulation_control==0)
    % update index iterations
    uloop = uloop + 1;
    
    sigma_N(uloop) = sum(n);

    if (uloop>=umax)
        display(['Simulation time exceeded umax, u=', num2str(uloop)])
        simulation_control=1;
        simulation_stable=0;
    end
    
    recount_nodes();
    remap_connectivity();
    
	priorita=0;
    minimum=[];
    for j = 1:maxC
		% Find the maximum Phase angle (node to next transmit)
		maxPhase = max(currPhase{j});
		% node number that's firing.
		indice = (currPhase{j} == maxPhase);
		% convert the phase adjustment into an absoulte simulation time      
		zmin{j} = simulationTime{j} + (1 - maxPhase);
        minimum = min([minimum zmin{j}]);
		% find the channel which must be serviced first
		if (zmin{j} <= minimum)
		    priorita=j; % if the new channel needs attention first, set this to the priority.
		end
		minimum=min([minimum zmin{j}]);
    end
    check_channel_node_left(priorita);
    check_channel_node_join(priorita);
    calculate_NE(priorita);
	channel_computation(priorita);
	check_channel(priorita);
    check_data_possible(priorita);
    
    % print the initial disposition of node
    if((uloop==2) && (figures>0))
        figure(1)
        subplot(1,2,1)
        set(gca,'ytick',0:maxC)
        
        for k = 1:maxC
			for j = 1:n(k)
				plot(currPhase{k}(j),k,'o','Color','k','MarkerFaceColor','k')
				text(currPhase{k}(j), (k + 0.1), num2str(j));            
				hold on
			end
		end
		      
        grid on
        
        %text(0.42, 0.25, ['Interation ' num2str(u)]);
        
        axis([-0.1 1.1 0.5 16.5]); % scale the graph nicely :)
        title('Initial Node Locations');
        xlabel('Firing Angle');
        ylabel('Channel Number');
        hold off
        refreshdata
        drawnow
    end
    
    minIterations = [];
    for j=1:maxC
        minIterations = min([minIterations iterations{j}]);
    end
    
    if (minIterations >= itsmax)
        simulation_control = 1;
    end
    
    vertical_ok = 0;
    itsConverged_ok = 0; 
    currPhase_ok = 0;

    for j = 1:maxC
        if ((vertical_node(1,j)>0))
            vertical_ok = vertical_ok + 1;
            if (currPhase{j}(vertical_node(1,j))==0)
                currPhase_ok = currPhase_ok + 1;
            end
        end
        if (convergedIterations{j}>10)
            itsConverged_ok = itsConverged_ok + 1;
        end
    end

    % print the final disposition of node
    if( (vertical_ok == maxC) && (itsConverged_ok == maxC) && (currPhase_ok == maxC) )
	status('NETWORK STABLE','')
    
    for j=1:maxC
        maxIterations = max([maxIterations iterations{j}]);
    end
    
    if (convIterations < 0)
        if(maxC==1)
            convIterations = maxIterations;
        else
            convIterations = maxIterations - (convergenceIterations*(ChurnDepth==0));
        end
    end
    
    simulation_control = 1;
    %save('Subroutines_Churn.mat');
	simulation_stable = 1;

        if (figures>0)
            figure(1)
            subplot(1,2,2)
            set(gca,'ytick',0:maxC)
            
            for k = 1:maxC
                text(currPhase{k}(vertical_node(1,k)), (k+0.3), 'S','Color','r');
                hold on
            end
            grid on
            
            %t=1;
            for k = 1:maxC
                for j = 1:n(k)
                    plot(currPhase{k}(j),k,'o','Color','k','MarkerFaceColor','k')
                    text(currPhase{k}(j), (k+0.1), num2str(j));
                    hold on
                end
            end
            
            %text(0.42, 0.25, ['Interation ' num2str(u)]);
            
            axis([-0.1 1.1 0.5 16.5]); % scale the graph nicely :)
            title('Final Node Locations');
            xlabel('Firing Angle');
            ylabel('Channel Number');
            set(gca,'ytick',0:maxC)
            hold off
            refreshdata
            drawnow
        end
    end
    for j = 1:maxC
		gs{j} = [gs{j} n(j)];
    end
end

%% data plot
% printing final value of channels
display('------------------------------------------------------------')
display('--------------------SIMULATION COMPLETED--------------------')
display('------------------------------------------------------------')
display(' ')
display(['Final number of nodes per channel --> ',num2str(n)])
display(['Final sync nodes --> ',num2str(vertical_node)])
display(' ')

% report -1 iterations as a failure
if (simulation_stable == 0)
    maxIterations = -1;
end

if (figures>0)
    figure(1)
    subplot(1,2,1)
    set(gca,'ytick',0:maxC)
    box on
    refreshdata
    drawnow
    %figure(2)
    figure(1)
    subplot(1,2,2)
    set(gca,'ytick',0:maxC)
    box on
    refreshdata
    drawnow
end

% if (figures>0)
%     figure(2)
%     for k = 1:maxC
%         gsl{k} = plot(gs{k}, 'k');
%         hold on
%     end
%     title('Channel Node Population');
%     xlabel('Iteration');
%     ylabel('Number of Nodes in Channel');
%     set(gca,'ytick',0:10)
%     box on
%     axis([0 500 (min(min(min(gs{4}),min(gs{3})),min(min(gs{2}),min(gs{1})))-1) (max(max(max(gs{4}),max(gs{3})),max(max(gs{2}),max(gs{1})))+1)]); % scale the graph nicely :)
%     
% end

%save('everything.mat');
%error('asdf')

% plot
if ((simulation_control==1) && (figures>0))
    % plot fires
    figure (3)
    
    for k = 1:maxC
		plot(st{k},k,'o','Color','k','MarkerFaceColor','k')
		hold on
	end
    
    set(gca,'ytick',0:17)
    title('Node Firing Events');
	xlabel('Simulation Time [s]');
	ylabel('Channel Number');
    grid on
    ylim([0 17])
    
    
    for k = 1:maxC
        [mst, nst]=size(simtime_sinkfire_storage{k});
        for es1=1:1:mst
            for es=1:1:nst
                text(simtime_sinkfire_storage{k}(es1,es),(k+0.4), 'S','Color','r');
                text(simtime_sinkfire_storage{k}(es1,es),(k+0.2), num2str(es1),'Color','r');
            end
        end
    end

    % plot difference in phase vs iteretions
    y=0;
    
    for k = 1:maxC
		diff{k} = 0;
		[m,sn{k}]=size(st{k});
		diff{k}(1)=st{k}(1)-0;
    end

    figure (4)
    
	for k=1:maxC
		for i=2:1:sn{k}
			diff{k}(i)=st{k}(i)-st{k}(i-1);
			yn{k}(i)=i;
		end
		plot(yn{k},diff{k},'Color','k')
		hold on
	end
	
    grid on
    
    w=1./n;
    for k = 1:maxC
        % plot threshold
        wpiu=w(1,k)+desyncThreshold;
        wmeno=w(1,k)-desyncThreshold;
        plot(yn{k},wpiu,'Color','k')
        plot(yn{k},wmeno,'Color','k')
    end
    legend('Gap between phase channel 1','Gap between phase channel 2','Gap between phase channel 3','Gap between phase channel 4','Positive Treshold','Negative Treshold')
    

    grid on

    
    %legend('Gap between phase channel 1','Gap between phase channel 2','Gap between phase channel 3','Gap between phase channel 4','Positive Treshold','Negative Treshold')
    
    % figure (7)
    % subplot(2,1,1)
    % plot(y4,diff4,'Color','k')
    % title('Phase Differences in Consecutive Firings');
    % xlabel('Iteration');
    % ylabel('Time between firings [s]');
    % legend ('Single Channel');
    % axis([0 max(y3) 0 max(diff3)+0.05])
    % box on
    % grid on
    
    figure (5)
    % subplot(2,1,2)
    for j = 1:maxC
        plot(yn{j},diff{j},'k')
        hold on
    end
    
   
    title('Phase Differences in Consecutive Firings');
    xlabel('Iteration');
    ylabel('Time between firings [s]');
    legend('Channel 1', 'Channel 2', 'Channel 3', 'Channel 4', 'Channel 5', 'Channel 6', 'Channel 7', 'Channel 8', 'Channel 9', 'Channel 10', 'Channel 11', 'Channel 12', 'Channel 13', 'Channel 14', 'Channel 15', 'Channel 16');
    %axis([0 max([max(y1) max(y2) max(y3) max(y4)  max(y5) max(y6) max(y7) max(y8) max(y9) max(y10) max(y11) max(y12) max(y13) max(y14) max(y15) max(y16)]) 0 max([max(diff1) max(diff2) max(diff3) max(diff4) max(diff5) max(diff6) max(diff7) max(diff8) max(diff9) max(diff10) max(diff11) max(diff12) max(diff13) max(diff14) max(diff15) max(diff16)])+0.05])
    %axis([0 120 0 max([max(diff1) max(diff2) max(diff3) max(diff4)])+0.05])
    box on
    grid on
    
    
%     figure(6)
%     plot(sigma_N)
%     title('Number of Real + Ghost Nodes in Network');
%     xlabel('Internal Simulator Loop Variable / uloop');
%     ylabel('Number of Nodes / Real + Ghost');
end

% Plots balancing figure for paper, showing just 4 channels - disable NC if
% plotting this.
%     figure(7)
%     plot(gs{1}, 'r')
%     hold on
%     plot(gs{2}, 'g')
%     plot(gs{3}, 'b')
%     plot(gs{4}, 'k')
%     legend('Channel 1', 'Channel 2', 'Channel 3', 'Channel 4');
%     
%     title('Channel Node Population');
%     xlabel('Iteration');
%     ylabel('Number of Nodes in Channel');
%     set(gca,'ytick',0:10)
%     box on
%     axis([1 max([length(gs{1}) length(gs{2}) length(gs{3}) length(gs{4})]) (min(min(min(gs{4}),min(gs{3})),min(min(gs{2}),min(gs{1})))-1) (max(max(max(gs{4}),max(gs{3})),max(max(gs{2}),max(gs{1})))+1)]); % scale the graph nicely :)


% % save average data in a file
% if(uloop<umax && simulation_control==1)
%     convergence_itereation_total=itsConverged1+itsConverged2+itsConverged3+itsConverged4+itsConverged5+itsConverged6+itsConverged7+itsConverged8+itsConverged9+itsConverged10+itsConverged11+itsConverged12+itsConverged13+itsConverged14+itsConverged15+itsConverged16;
%     average_channel=convergence_itereation_total/16;
%     fileaverage=fopen('average_iteration.txt','a');
%     fprintf(fileaverage,'%f\n',average_channel);
%     fclose(fileaverage);
%     
%     convergence_time_total=s11+s12+s13+s14+s15+s16+s17+s18+s19+s110+s111+s112+s113+s114+s115+s116;
%     average_time=convergence_time_total/16;
%     fileaverage2=fopen('average_time.txt','a');
%     fprintf(fileaverage2,'%f\n',average_time);
%     fclose(fileaverage2);
% end

%% Data calculation

% This section of code calculates the data sent by the network.  It assumes
% that sent_data_packets{x}(y) containes the convergence status for each
% channel (x) at iteration (y).

% By summing the iterations over y we can find how many packets were sent
% on each channel.  If a channel is converged at a given iteration, then
% sent_data_packets{x}(y) is true (else false).  Multiply number of nodes
% and packets_per_beacon gives the total number of beacons sent, which is
% finally multiplied by the probability of success.

channel_total_packets = zeros(1,maxC);
for j=1:maxC
    for k=1:max(iterations{j})
        channel_total_packets(j) = channel_total_packets(j) + ((sent_data_packets{j}(k) * n(j) * packets_per_beacon) * (rand()<=(1-p_packetloss(j))));
    end
end


%% Calculate initial value of the objective function
for j = 1:maxC
   sortedInitPhase = sort(initialPhase{j});
   g_0_allChan(j) = 0.5*(norm(D*(sortedInitPhase')-uVec+eVec))^2;
   %g_0_allChan(j) = 0.5*(norm(D*(sortedInitPhase')-uVec))^2;
   sortedPhase = sort(currPhase{j})
   g_star = 0.5*(norm(D*(sortedPhase')-uVec+eVec))^2
   %g_star = 0.5*(norm(D*(sortedPhase')-uVec))^2
end
g_0 = mean(g_0_allChan);
%test
% pfactor = 1/NumberOfNodes;
% p = pfactor:pfactor:1;
% g_test = 0.5*(norm(D*(p')-uVec+eVec))^2;

%%
total_packets = sum(channel_total_packets);
maxGhosts = (max(sigma_N) - sum(ninit));
    
z = convIterations;
v = maxIterations;
%x = total_packets;
x = g_0;
display('ConvIterations now has 10 removed.')

end

