 
function [gating_signal2,W] = PCA_ICA_gating_signal(ksp2,params)

% for chan=1:params.nc;
% gating_signal(chan,:)=sum(abs(ksp2(params.cksp,:,:,chan)),3);
% end
clear gating_signal

for chan=1:params.nc;
for nz=1:params.nz
gating_signal(nz,chan,1,:)=abs(ksp2(params.cksp,:,nz,chan));
gating_signal(nz,chan,1,:)=imag(ksp2(params.cksp,:,nz,chan));
gating_signal(nz,chan,2,:)=real(ksp2(params.cksp,:,nz,chan));
% gating_signal(nz,chan,4,:)=angle(real(ksp2(params.cksp,:,nz,chan))+1j*imag(ksp2(params.cksp,:,nz,chan)));
% gating_signal(nz,chan,5,:)=sum(abs(ksp2(:,:,nz,chan)).^2);

end
end

%reshape gating_signal
gating_signal=reshape(gating_signal,[size(gating_signal,1)*size(gating_signal,2)*size(gating_signal,3),params.nspokes]);

% remove the mean variable-wise (row-wise)
data=gating_signal';
size(repmat(mean(data,1),[size(data,1) 1]));
data=data-repmat(mean(data,1),[size(data,1) 1]);

%scale by sigma
Vardata=std(data);
data=data./repmat(Vardata,[params.nspokes 1]);



if params.visualize==1;
figure(992); imshow(data,[]); title('input data for PCA'); xlabel('coil*slice dimension');ylabel('time (Fs)');end

% calculate eigenvectors (loadings) W, and eigenvalues of the covariance matrix
[W, EvalueMatrix] = eig(cov(data'));
Evalues = diag(EvalueMatrix);

% order by largest eigenvalue
Evalues = Evalues(end:-1:1);
W = W(:,end:-1:1); W=W';
%% take first n princpal components
PCAVar=params.PCAVar;

idx=find((cumsum(Evalues)./sum(Evalues))>PCAVar);
nPCA=idx(1);
disp(['taking the first ',num2str(nPCA),' principal components'])
gating_signal=W(1:nPCA,:);

%% do ICA

if params.visualize==1;
figure(994); imshow(gating_signal.',[]); title('input data for ICA'); xlabel('coil*slice dimension');ylabel('time (Fs)');end


nICA=params.nICA;
[W] = myICA(gating_signal,nICA);



% generate PCA component space (PCA scores)
% pc = W * data;

%find which PC has the most energy in a prescribed frequency band:
GAfreq=params.Fs*(params.goldenangle/360); %freq of GA signal
if GAfreq<params.PCAfreqband(1) %ok
elseif GAfreq>params.PCAfreqband(2) %ok
else; fprintf(2,'WARNING: params.PCAfreqband includes the goldenangle frequency!!! \n'); end

freqs=linspace(-0.5,0.5,length(W(1,:)))*params.Fs;
FW=abs(fftshift(fft(W,[],2),2));

bandfreqs= (freqs < params.PCAfreqband(2)).*(freqs > params.PCAfreqband(1));
outbandfreqs= (freqs < params.PCAfreqband(1))+(freqs > params.PCAfreqband(2));

EnergyIC=sum(FW(:,logical(bandfreqs)).^2,2);
EnergyIC_outband=sum(FW(:,logical(outbandfreqs)).^2,2);
RelEnergy=EnergyIC./EnergyIC_outband;

[~,indexPC]=sort(RelEnergy,'descend');
PCA_choice=indexPC(1);

if isfield(params,'PCA_PCnr'); %if specified; use certain PC instead of the one with max energy (temporary option?)
    disp('PCA chosen bases on param.PCA_PCnr instead of max energy in specified frequency band!')
    gating_signal2=double(W(params.PCA_PCnr,:));
    PCA_choice=params.PCA_PCnr;
end


if params.visualize==1;
    
    figure(995); hold on ;
    for ii=1:nICA;
        tvector=linspace(0,params.nspokes/params.Fs,params.nspokes);
        plot(tvector,(ii*4)+W(ii,:));
        text(tvector(5),(ii*4-(2)),['Independent component ',num2str(ii),', Rel. Energy in f-band :' ,num2str(RelEnergy(ii))])
        if ii==PCA_choice;
           text(tvector(end),4*ii,'chosen IC') 
        end
    end
    title('ICA analysis: first n independent components')
    xlabel('time (s)')
    ylabel('')
    hold off

    %%%%%
    
    
    [~, GAfreqindex]=sort(abs(freqs-GAfreq),'ascend');
    figure(993);
    hold on 
    L=floor(length(FW)/2);
    stem(freqs(L:end),FW(PCA_choice,L:end),'r');
    stem(freqs(logical(bandfreqs)),FW(PCA_choice,logical(bandfreqs)),'b');
    text(freqs(GAfreqindex(1)),double(FW(PCA_choice,GAfreqindex(1))),'*Golden Angle Frequency')
    hold off
    title('spectrum of chosen independent component');
    xlabel('frequency (Hz)');  ylabel('abs value of component')
end

gating_signal2=double(W(PCA_choice,:));


end