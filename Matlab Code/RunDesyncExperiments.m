
%% Run Desync in one channel
clear all
close all
NumberOfTrials = 2;
n=8;

tic;
for th=1:1:2
    threshold = 10^(-(th+3));
    a = 0;
    for coupling=0.05:0.05:0.95
        display(coupling, 'coupling')
        aver = zeros(1,NumberOfTrials);
        initErr = zeros(1,NumberOfTrials);
        averNest = zeros(1,NumberOfTrials);
        a = a+1;
        i = 1;
        while (i<NumberOfTrials)
            [x, y, z] = SIMPLEalterCriter(0,0,0,n,0,coupling,threshold);
            if(x>0)
                aver(i) = x;
                initErr(i) = z;
                i = i+1;
            end
        end
        j = 1;
        while(j<NumberOfTrials)
            [x1, y1, z1] = SIMPLEalterCriter(0,0,0,n,1,coupling,threshold);
            if(x1>0)
                averNest(j) = x1;
                j=j+1;
            end
        end
        A4(th,a) = mean(aver);
        A4Nest(th,a) = mean(averNest);
        A4max(th,a) = max(aver);
        A4Nestmax(th,a) = max(averNest);
        Init4(th,a) = mean(initErr(aver>0));
    end
end
ElapsedTime = toc


fID1 = fopen('NoNest.txt','w');
fprintf(fID1,'%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\n',A4');
fprintf(fID1,'\n');
fprintf(fID1,'%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\n',A4max');
fprintf(fID1,'\n');
fprintf(fID1,'%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\n',Init4');
fclose(fID1);

fID2 = fopen('withNest.txt','w');
fprintf(fID2,'%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\n',A4Nest');
fprintf(fID2,'\n');
fprintf(fID2,'%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\t%5.3f\n',A4Nestmax');
fclose(fID2);

coupling=0.05:0.05:0.95;
figDesync('Desync Average', n, coupling, A4, A4Nest, Init4);
figDesyncWithBounds('Desync Max Error', n, coupling, A4max, A4Nestmax, Init4);