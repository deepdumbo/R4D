classdef GoldenAngle_Recon < MRecon
    properties
        %none 
    end
    
    methods
        function MR = GoldenAngle_Recon( filename )
            MR=MR@MRecon(filename);
        end
        % Overload (overwrite) the existing Perform function of MRecon    
        function Perform( MR )
            MR.Perform1;    %reading and sorting data
            MR.CalculateAngles;
            MR.PhaseShift;
            MR.PerformGrid;
            MR.Perform2;
        end
        
        function Perform1( MR )            
            %Reconstruct only standard (imaging) data
            MR.Parameter.Parameter2Read.typ = 1;                        
            % Produce k-space Data (using MRecon functions)
            disp('Reading data...')
            MR.ReadData;
            disp('Corrections...')
            MR.DcOffsetCorrection;
            MR.PDACorrection;
            MR.RandomPhaseCorrection;
            MR.MeasPhaseCorrection;
            disp('Sorting data...')
            MR.SortData;
            disp('Perform part 1 finished')
        end
        function CalculateAngles(MR)
            disp('Calculating angles...')
            try 
                goldenangle=MR.Parameter.GetValue('`CSC_golden_angle');
            catch
                goldenangle=MR.Parameter.GetValue('`EX_ACQ_radial_golden_ang_angle');
            end
            
            Npe=MR.Parameter.Scan.Samples(2); %number of phase-encoding lines
            
            if MR.Parameter.Parameter2Read.ky(1)==0
            angles=[0:(goldenangle)*(pi/180):(Npe-1)*(goldenangle)*(pi/180)]; %relative angles measured (first set at 0)
            else
                angleshift=(double(MR.Parameter.Parameter2Read.ky(1))*(goldenangle*(pi/180)));
                angles=[angleshift:(goldenangle)*(pi/180):(Npe-1)*(goldenangle)*(pi/180)+angleshift]; %relative angles measured (first set at 0)
            end
            
            MR.Parameter.Gridder.RadialAngles=angles';
        end
        
        function PhaseShift(MR)
            %Trajectory correction for free-breathing radial MRI 
            %Buonincontrini, Sawiak, Caprenter
            disp('Phase Shift (Eddy current) correction...')
            angles=MR.Parameter.Gridder.RadialAngles(1:size(MR.Data,2))'; %only use angles for which there is data

            anglesrad=mod(angles,2*pi);
            cksp=floor(size(MR.Data,1)/2)+1; %how to find it generally?
            
            for nechoes=1:size(MR.Data,7)
            for nc=1:size(MR.Data,4)
                for nz=floor(size(MR.Data,3)/2)+1;
                    fprintf('%d -',nc)
                    y=unwrap(angle(MR.Data(cksp,:,nz,nc))); %phase of center of k-space (with corrected k: find closest to zero?!?!)
                    Gx=1;Gy=1;
                    x=[ones(size(anglesrad))',Gx.*cos(anglesrad'),Gy.*sin(anglesrad')];
                    beta=inv(x'*x)*x'*y';
                    phiec=(beta(2)*cos(angles)+beta(3)*sin(angles));
                    kspcorr(:,:,:,nc,1,1,nechoes)=((MR.Data(:,:,:,nc))).*repmat(exp(-1i.*phiec),[size(MR.Data,1) 1 size(MR.Data,3)]);
                end
            end
            end
            MR.Data=kspcorr;
        end
        
        function PerformGrid(MR)
            disp('Gridding data...')
            MR.GridderCalculateTrajectory;
            MR.Parameter.Gridder.AlternatingRadial='no';
            [nx,ntviews,nz,nc]=size(MR.Data);            
            
            try
            goldenangle=MR.Parameter.GetValue('`EX_ACQ_radial_golden_ang_angle');
            catch            
                goldenangle=MR.Parameter.GetValue('`CSC_golden_angle');
            end
            k=buildRadTraj2D(nx,ntviews,false,true,true,[],[],[],[],goldenangle);
            %             wu=calcDCF(k,MR.Parameter.Encoding.XReconRes); %calculate better weights
            wu=getRadWeightsGA(k);
            MR.Parameter.Gridder.Weights=wu;
            MR.GridData;

        end
        function Perform2(MR)
            disp('Ringing Filter')
            MR.RingingFilter;
            MR.ZeroFill
            disp('Converting to image space...')
            MR.K2I;
            MR.GridderNormalization;

            disp('SENSE unfold...')
            MR.SENSEUnfold;
            MR.ConcomitantFieldCorrection;
            disp('Combining Coils...')
            MR.CombineCoils;
            MR.Average;
            MR.GeometryCorrection;
            MR.RemoveOversampling;
            disp('Zerofilling...')
            MR.ZeroFill;
            MR.RotateImage;
            disp('Reconstruction finished')
        end
        
        function CheckAllChannels(MR) %function to do whole recon without comboining coils
            disp('Check All Channels - recon of all coil channels separately')
            MR.Parameter.Parameter2Read.chan
            MR.Perform1;    %reading and sorting data
            MR.CalculateAngles;
            MR.PhaseShift;
            MR.PerformGrid;
            MR.RingingFilter;
            MR.ZeroFill
            MR.K2I;
            MR.GridderNormalization;
            MR.ShowData
        end        
        
        
    end
   
    
    % These functions are Hidden to the user
    methods (Static, Hidden)

    end
end