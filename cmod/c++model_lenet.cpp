//c++model_lenet.cpp 에서 Bias를 추가했다.

#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <vector>
//#include <string>
#include <algorithm>
#include <math.h>
#include <ctime>
#include <opencv2/opencv.hpp> //openCV 사용
using namespace cv;
using namespace std;

class Label{        //matching name class
    public:
        char label;
        float weight;
        Label(char label, float weight){
            this->label=label;
            this->weight=weight;
        }
        bool operator <(Label &num){        //'<' : 연산자 오버로딩
            return this->weight < num.weight;
    }
};

vector<Label> Softmax(vector<float> &Y){    //Softmax layer
    vector<Label> SY;
    float i,j,sum=0;
    float max = *max_element(Y.begin(),Y.end());
    SY.push_back(Label('0',Y.at(0)));   //labeling
    SY.push_back(Label('1',Y.at(1)));
    SY.push_back(Label('2',Y.at(2)));
    SY.push_back(Label('3',Y.at(3)));
    SY.push_back(Label('4',Y.at(4)));
    SY.push_back(Label('5',Y.at(5)));
    SY.push_back(Label('6',Y.at(6)));
    SY.push_back(Label('7',Y.at(7)));
    SY.push_back(Label('8',Y.at(8)));
    SY.push_back(Label('9',Y.at(9)));
    sort(SY.begin(),SY.end());          //sorting
    reverse(SY.begin(),SY.end());       //내림차순
    for(j=0;j<SY.size();j++){               //softmax
        sum += exp(SY.at(j).weight-max);    //모든 weight에 max값을 빼줌으로써 overflow 방지
    }
    for(i=0;i<SY.size();i++){
        SY.at(i).weight = exp(SY.at(i).weight-max)/sum;
    }
    return SY;
}

void getActivation(vector<float> &Y){   //RelU
    for(int i=0;i<Y.size();i++){        //x<0 이면 y=0
        if(Y.at(i)<0) Y.at(i) = 0;      //x>0 이면 y=x
    }
}

vector<float> Fullyconnected(vector<float> &X, Mat &W, vector<float> &B){     //fully connected layer
    int i,j;
    float sum=0;
    vector<float> Y;
    for(i=0;i<W.size[0];i++){
        for(j=0;j<X.size();j++){        //fully connected
            sum += W.at<float>(i,j)*X.at(j);
        }
        sum += B.at(i);
        Y.push_back(sum);
        sum=0;
    }
    return Y;
}

Mat MaxPooling(Mat& Y, int kernel, int st){     //pooling layer
    int d,k,m,n,i,j;
    float max;
    int PY_row=(Y.size[2]-kernel)/st+1;
    int PY_col=(Y.size[3]-kernel)/st+1;
    int st_row=0;
    int st_col=0;
    int size[]={Y.size[0],Y.size[1],PY_row,PY_col};
    Mat PY(4,size,Y.type());
    for(d=0;d<PY.size[0];d++){
        for(k=0;k<PY.size[1];k++){
            for(m=0;m<PY.size[2];m++){
                for(n=0;n<PY.size[3];n++){
                    for(i=0;i<kernel;i++){
                        for(j=0;j<kernel;j++){
                            if(i==0&&j==0)
                                max=Y.at<float>(Vec<int,4>(d,k,i+st_row,j+st_col));     //max 초깃값
                            else if(Y.at<float>(Vec<int,4>(d,k,i+st_row,j+st_col))>max)   //find max value
                                max=Y.at<float>(Vec<int,4>(d,k,i+st_row,j+st_col));
                        }
                    }
                    PY.at<float>(Vec<int,4>(d,k,m,n))=max;  //max 출력
                    st_col+=st;
                }
                st_row+=st;
                st_col=0;
            }
            st_row=0;
        }
    }
    return PY;
}
Mat Convolution(int N, Mat& X, Mat& W, vector<float> &B, const int P, const int S){     //convolution layer
    int i,j,k,l,m,n,q;
    int row_s=0,col_s=0;
    int dim = 4;                //dimention
    int Y_row = (X.size[2]-W.size[2]+2*P)/S+1;      //output size
    int Y_col = (X.size[3]-W.size[3]+2*P)/S+1;
    int y_size[] = {N,W.size[0],Y_row,Y_col};
    Mat Y= Mat::zeros(dim,y_size,CV_32F);           //output 초깃값 0, 초기화를 안하면 연산시 오류
    int x_size[] = {N,X.size[1],X.size[2]+2*P,X.size[3]+2*P};
    Mat XP(dim,x_size,CV_32F);                              //padded input
    for(n=0;n<XP.size[0];n++){
        for(k=0;k<XP.size[1];k++){
            for(i=0;i<XP.size[2];i++){ 
                for(j=0;j<XP.size[3];j++){
                    if((i<P)||(i>X.size[2]+P-1))            //padding
                        XP.at<float>(Vec<int,4>(n,k,i,j))=0;
                    else if((j<P)||(j>X.size[3]+P-1))
                        XP.at<float>(Vec<int,4>(n,k,i,j))=0;
                    else
                        XP.at<float>(Vec<int,4>(n,k,i,j))=X.at<float>(Vec<int,4>(n,k,i-P,j-P));
                }
            }
        }
    }
    for(n=0;n<Y.size[0];n++){
        for(q=0;q<Y.size[1];q++){           //Convolution
            for(m=0;m<Y.size[2];m++){
                for(i=0;i<Y.size[3];i++){
                    for(k=0;k<W.size[1];k++){
                        for(j=0;j<W.size[2];j++){              //필터와 입력데이터 곱셈
                            for(l=0;l<W.size[3];l++){
                                Y.at<float>(Vec<int,4>(n,q,m,i)) += XP.at<float>(Vec<int,4>(n,k,j+row_s,l+col_s))*W.at<float>(Vec<int,4>(q,k,j,l)); //곱셈의 합
                            }
                        }       
                    }
                    Y.at<float>(Vec<int,4>(n,q,m,i)) += B.at(q);
                    col_s+=S;   //column이 stride만큼 증가   
                }
                col_s=0;        //column 초기화, row가 stride만큼 증가
                row_s+=S;
            }
            row_s=0;            //row 초기화
        }
    }
    return Y;
}

int main(){
    clock_t start = clock();    //프로그램 실행부터 현재까지의 시간
    int i,j,k,l;
    int num = 1;          //입력의 개수

    Mat img;
    img = imread("test/test8.jpg",IMREAD_GRAYSCALE);  //이미지 읽기, IMREAD_GRAYSCALE = CV_8U
    if(img.empty()){
        cout<<"Could not open of find the image"<<endl;     //이미지를 못 읽었을 경우 오류 처리
        return -1;
    }
    int x_size[]={num,img.channels(),img.rows,img.cols};
    Mat input(4,x_size,CV_32F);                //image file -> Mat 4D array
    for(l=0;l<input.size[0];l++){
        for(k=0;k<input.size[1];k++){
            for(i=0;i<input.size[2];i++){
                for(j=0;j<input.size[3];j++){
                    input.at<float>(Vec<int,4>(l,k,i,j)) = img.at<uchar>(i,j);  // 흑백 반전: 255 - img.at<uchar>(i,j);
                }
            }
        }
    }

    FILE *fp;
    char dump[32];             //필요없는 문자열을 담을 변수

    fp=fopen("test/weights2.json","r"); //파일 읽기
    if(fp==NULL){
		printf("Read Error!\n");        //파일을 못 읽었을 경우 오류 처리
		return 0;	
	}

    int kernel = 2;         //풀링의 kernel과 stride
    int stride_pool = 2;    //입출력의 크기를 맞추려면 padding = (Filter size-1)/2 로 하면 된다.
    int padding = 0;        //필터의 padding과 stride
    int stride = 1;

    int conv1_num,conv1_channel,conv1_rows,conv1_cols;
    fscanf(fp,"%s",dump);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%d",&conv1_num); 
    fscanf(fp,"%s",dump);
    fscanf(fp,"%d",&conv1_channel);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%d",&conv1_rows);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%d",&conv1_cols);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%c",dump);
    vector<float> conv1_b(conv1_num);           //conv1 bias 
    for(i=0;i<conv1_num;i++){                   //json 파일로부터 bias값을 fscanf
        fscanf(fp,"%f",&conv1_b.at(i));
        fscanf(fp,"%s",dump);
    }

    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    int conv1_size[] = {conv1_num,conv1_channel,conv1_rows,conv1_cols};
    Mat conv1_w(4,conv1_size,CV_32F);       
    for(l=0;l<conv1_w.size[0];l++){             //conv1 weight 
        fscanf(fp,"%c",dump);                   //json 파일로부터 weight값을 fscanf
        for(k=0;k<conv1_w.size[1];k++){
            fscanf(fp,"%c",dump);
            for(i=0;i<conv1_w.size[2];i++){
                fscanf(fp,"%c",dump);
                fscanf(fp,"%c",dump);
                for(j=0;j<conv1_w.size[3];j++){
                    fscanf(fp,"%f",&conv1_w.at<float>(Vec<int,4>(l,k,i,j)));
                    fscanf(fp,"%s",dump);
                }
            }
        }
    }

    Mat conv1 = Convolution(num,input,conv1_w,conv1_b,padding,stride);    //convolution layer1
    Mat pool1 = MaxPooling(conv1,kernel,stride_pool);                   //max pooling layer1

    int conv2_num,conv2_channel,conv2_rows,conv2_cols;
    fscanf(fp,"%s",dump);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%d",&conv2_num);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%d",&conv2_channel);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%d",&conv2_rows);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%d",&conv2_cols);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%c",dump);
    vector<float> conv2_b(conv2_num);           //conv2 bias 
    for(i=0;i<conv2_num;i++){                   //json 파일로부터 bias값을 fscanf
        fscanf(fp,"%f",&conv2_b.at(i));
        fscanf(fp,"%s",dump);
    }

    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    int conv2_size[] = {conv2_num,conv2_channel,conv2_rows,conv2_cols};
    Mat conv2_w(4,conv2_size,CV_32F);
    for(l=0;l<conv2_w.size[0];l++){             //conv2 weight
        fscanf(fp,"%c",dump);                   //json 파일로부터 weight값을 fscanf
        for(k=0;k<conv2_w.size[1];k++){
            fscanf(fp,"%c",dump);
            for(i=0;i<conv2_w.size[2];i++){
                fscanf(fp,"%c",dump);
                fscanf(fp,"%c",dump);
                for(j=0;j<conv2_w.size[3];j++){
                    fscanf(fp,"%f",&conv2_w.at<float>(Vec<int,4>(l,k,i,j)));
                    fscanf(fp,"%s",dump);
                }
            }
        }
    }   
    Mat conv2 = Convolution(num,pool1,conv2_w,conv2_b,padding,stride);    //convolution layer2
    Mat pool2 = MaxPooling(conv2,kernel,stride_pool);                   //max pooling layer2

    vector<float> pool2_v;          //Mat 4D array -> vector array
    for(l=0;l<pool2.size[0];l++){
        for(k=0;k<pool2.size[1];k++){
            for(i=0;i<pool2.size[2];i++){
                for(j=0;j<pool2.size[3];j++){
                    pool2_v.push_back(pool2.at<float>(Vec<int,4>(l,k,i,j)));
                }
            }
        }
    }

    int ip1_num,ip1_channel;
    fscanf(fp,"%s",dump);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%d",&ip1_num);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%d",&ip1_channel);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%c",dump);
    vector<float> ip1_b(ip1_num);           //ip1 bias 
    for(i=0;i<ip1_num;i++){                 //json 파일로부터 bias값을 fscanf
        fscanf(fp,"%f",&ip1_b.at(i));
        fscanf(fp,"%s",dump);
    }

    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    int ip1_size[] = {ip1_num,ip1_channel};
    Mat ip1_w(2,ip1_size,CV_32F);                   //ip1 weight
    for(i=0;i<ip1_w.size[0];i++){                   //json 파일로부터 weight값을 fscanf
        fscanf(fp,"%c",dump);
        fscanf(fp,"%c",dump);
        for(j=0;j<ip1_w.size[1];j++){
            fscanf(fp,"%f",&ip1_w.at<float>(i,j));
            fscanf(fp,"%s",dump);

        }
    }
    vector<float> ip1 = Fullyconnected(pool2_v,ip1_w,ip1_b);    //fully connected layer1

    getActivation(ip1);                                   //Activation layer

    int ip2_num,ip2_channel;
    fscanf(fp,"%s",dump);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%d",&ip2_num);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%d",&ip2_channel);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    fscanf(fp,"%c",dump);
    vector<float> ip2_b(ip2_num);               //ip2 bias 
    for(i=0;i<ip2_num;i++){                     //json 파일로부터 bias값을 fscanf
        fscanf(fp,"%f",&ip2_b.at(i));
        fscanf(fp,"%s",dump);
    }

    fscanf(fp,"%s",dump);
    fscanf(fp,"%c",dump);
    int ip2_size[] = {ip2_num,ip2_channel};
    Mat ip2_w(2,ip2_size,CV_32F);
    for(i=0;i<ip2_w.size[0];i++){           //ip2 weight
        fscanf(fp,"%c",dump);               //json 파일로부터 weight값을 fscanf
        fscanf(fp,"%c",dump);
        for(j=0;j<ip2_w.size[1];j++){
            fscanf(fp,"%f",&ip2_w.at<float>(i,j));
            fscanf(fp,"%s",dump);

        }
    }
    vector<float> ip2 = Fullyconnected(ip1,ip2_w,ip2_b);    //fully connected layer2

    vector<Label> prob = Softmax(ip2);                //softmax layer

    for(l=0;l<5;l++){       //check TOP-5
        cout<<fixed;        //cout 소수점 고정
        cout.precision(4);  //cout 소수점 4자리까지 확인
        cout<<prob[l].weight<<" - '"<<prob[l].label<<"'"<<endl;
    }

    fclose(fp);             //파일 닫기
    printf("time: %0.5fs\n",(float)(clock() - start)/CLOCKS_PER_SEC);   //알고리즘 시간측정

    return 0;
}